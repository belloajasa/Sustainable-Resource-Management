;; Extraction Tracking Contract
;; Records resource utilization

(define-data-var admin principal tx-sender)

;; Extraction data structure
(define-map extractions
  { extraction-id: (string-ascii 36) }
  {
    resource-id: (string-ascii 36),
    amount: uint,
    unit: (string-ascii 16),
    extracted-by: principal,
    extracted-at: uint,
    location: (string-ascii 128)
  }
)

;; Resource balance tracking
(define-map resource-balances
  { resource-id: (string-ascii 36) }
  { total-extracted: uint }
)

;; Record a new extraction
(define-public (record-extraction (extraction-id (string-ascii 36))
                                 (resource-id (string-ascii 36))
                                 (amount uint)
                                 (unit (string-ascii 16))
                                 (location (string-ascii 128)))
  (let ((current-balance (default-to { total-extracted: u0 }
                          (map-get? resource-balances { resource-id: resource-id }))))
    (begin
      ;; Only authorized extractors can record
      (asserts! (or (is-eq tx-sender (var-get admin))
                   (is-authorized-extractor tx-sender))
               (err u403))

      ;; Record the extraction
      (map-set extractions
        { extraction-id: extraction-id }
        {
          resource-id: resource-id,
          amount: amount,
          unit: unit,
          extracted-by: tx-sender,
          extracted-at: block-height,
          location: location
        }
      )

      ;; Update the resource balance
      (map-set resource-balances
        { resource-id: resource-id }
        { total-extracted: (+ (get total-extracted current-balance) amount) }
      )

      (ok true)
    )
  )
)

;; Authorized extractors
(define-map authorized-extractors
  { extractor: principal }
  { authorized: bool }
)

;; Check if an extractor is authorized
(define-read-only (is-authorized-extractor (extractor principal))
  (default-to false (get authorized (map-get? authorized-extractors { extractor: extractor })))
)

;; Authorize an extractor
(define-public (authorize-extractor (extractor principal))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) (err u403))
    (map-set authorized-extractors
      { extractor: extractor }
      { authorized: true }
    )
    (ok true)
  )
)

;; Revoke extractor authorization
(define-public (revoke-extractor (extractor principal))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) (err u403))
    (map-set authorized-extractors
      { extractor: extractor }
      { authorized: false }
    )
    (ok true)
  )
)

;; Get extraction details
(define-read-only (get-extraction (extraction-id (string-ascii 36)))
  (map-get? extractions { extraction-id: extraction-id })
)

;; Get total extracted for a resource
(define-read-only (get-total-extracted (resource-id (string-ascii 36)))
  (default-to { total-extracted: u0 }
    (map-get? resource-balances { resource-id: resource-id }))
)

;; Set a new admin
(define-public (set-admin (new-admin principal))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) (err u403))
    (var-set admin new-admin)
    (ok true)
  )
)
