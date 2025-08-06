;; Construction Progress Inspection Contract
;; Manages inspection scheduling and progress tracking

;; Constants
(define-constant CONTRACT-OWNER tx-sender)
(define-constant ERR-NOT-AUTHORIZED (err u200))
(define-constant ERR-INSPECTION-NOT-FOUND (err u201))
(define-constant ERR-INVALID-STATUS (err u202))
(define-constant ERR-INSUFFICIENT-PAYMENT (err u203))
(define-constant ERR-INVALID-INPUT (err u204))

;; Data Variables
(define-data-var inspection-counter uint u0)
(define-data-var inspection-fee uint u500)

;; Data Maps
(define-map inspections uint {
  permit-id: uint,
  property-address: (string-ascii 200),
  inspection-type: (string-ascii 50),
  requested-by: principal,
  inspector: (optional principal),
  scheduled-date: (optional uint),
  completed-date: (optional uint),
  status: (string-ascii 20),
  result: (optional (string-ascii 20)),
  notes: (optional (string-ascii 500)),
  fee-paid: uint
})

(define-map authorized-inspectors principal bool)

;; Authorization Functions
(define-public (add-inspector (inspector principal))
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
    (ok (map-set authorized-inspectors inspector true))
  )
)

(define-public (remove-inspector (inspector principal))
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
    (ok (map-delete authorized-inspectors inspector))
  )
)

;; Inspection Functions
(define-public (request-inspection
  (permit-id uint)
  (property-address (string-ascii 200))
  (inspection-type (string-ascii 50))
  (requested-date uint))
  (let ((inspection-id (+ (var-get inspection-counter) u1))
        (fee (var-get inspection-fee)))
    (asserts! (> permit-id u0) ERR-INVALID-INPUT)
    (asserts! (> (len property-address) u0) ERR-INVALID-INPUT)
    (asserts! (> (len inspection-type) u0) ERR-INVALID-INPUT)
    (asserts! (>= requested-date block-height) ERR-INVALID-INPUT)
    (try! (stx-transfer? fee tx-sender (as-contract tx-sender)))
    (map-set inspections inspection-id {
      permit-id: permit-id,
      property-address: property-address,
      inspection-type: inspection-type,
      requested-by: tx-sender,
      inspector: none,
      scheduled-date: (some requested-date),
      completed-date: none,
      status: "scheduled",
      result: none,
      notes: none,
      fee-paid: fee
    })
    (var-set inspection-counter inspection-id)
    (ok inspection-id)
  )
)

(define-public (assign-inspector (inspection-id uint) (inspector principal))
  (let ((inspection (unwrap! (map-get? inspections inspection-id) ERR-INSPECTION-NOT-FOUND)))
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
    (asserts! (default-to false (map-get? authorized-inspectors inspector)) ERR-NOT-AUTHORIZED)
    (asserts! (is-eq (get status inspection) "scheduled") ERR-INVALID-STATUS)
    (map-set inspections inspection-id (merge inspection {
      inspector: (some inspector),
      status: "assigned"
    }))
    (ok true)
  )
)

(define-public (complete-inspection
  (inspection-id uint)
  (result (string-ascii 20))
  (notes (string-ascii 500)))
  (let ((inspection (unwrap! (map-get? inspections inspection-id) ERR-INSPECTION-NOT-FOUND)))
    (asserts! (is-some (get inspector inspection)) ERR-NOT-AUTHORIZED)
    (asserts! (is-eq tx-sender (unwrap-panic (get inspector inspection))) ERR-NOT-AUTHORIZED)
    (asserts! (is-eq (get status inspection) "assigned") ERR-INVALID-STATUS)
    (asserts! (> (len result) u0) ERR-INVALID-INPUT)
    (map-set inspections inspection-id (merge inspection {
      completed-date: (some block-height),
      status: "completed",
      result: (some result),
      notes: (some notes)
    }))
    (ok true)
  )
)

;; Read-only Functions
(define-read-only (get-inspection (inspection-id uint))
  (map-get? inspections inspection-id)
)

(define-read-only (get-inspection-count)
  (var-get inspection-counter)
)

(define-read-only (is-authorized-inspector (inspector principal))
  (default-to false (map-get? authorized-inspectors inspector))
)

(define-read-only (get-inspection-fee)
  (var-get inspection-fee)
)
