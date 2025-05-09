;; Resource Verification Contract
;; Validates natural resource assets

(define-data-var admin principal tx-sender)

;; Resource data structure
(define-map resources
  { resource-id: (string-ascii 36) }
  {
    name: (string-ascii 64),
    type: (string-ascii 32),
    location: (string-ascii 128),
    verified: bool,
    verified-by: principal,
    verified-at: uint
  }
)

;; Verify a resource
(define-public (verify-resource (resource-id (string-ascii 36))
                               (name (string-ascii 64))
                               (type (string-ascii 32))
                               (location (string-ascii 128)))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) (err u403))
    (map-set resources
      { resource-id: resource-id }
      {
        name: name,
        type: type,
        location: location,
        verified: true,
        verified-by: tx-sender,
        verified-at: block-height
      }
    )
    (ok true)
  )
)

;; Check if a resource is verified
(define-read-only (is-resource-verified (resource-id (string-ascii 36)))
  (default-to false (get verified (map-get? resources { resource-id: resource-id })))
)

;; Get resource details
(define-read-only (get-resource (resource-id (string-ascii 36)))
  (map-get? resources { resource-id: resource-id })
)

;; Set a new admin
(define-public (set-admin (new-admin principal))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) (err u403))
    (var-set admin new-admin)
    (ok true)
  )
)
