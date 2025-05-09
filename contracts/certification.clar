;; Certification Contract
;; Validates sustainable practices

(define-data-var admin principal tx-sender)

;; Certification data structure
(define-map certifications
  { certification-id: (string-ascii 36) }
  {
    entity-id: (string-ascii 36),
    entity-type: (string-ascii 32), ;; "company", "project", "resource", etc.
    certification-type: (string-ascii 64),
    issued-at: uint,
    expires-at: uint,
    issuer: principal,
    status: (string-ascii 16), ;; "active", "expired", "revoked"
    sustainability-score: uint ;; 0-100
  }
)

;; Issue a new certification
(define-public (issue-certification (certification-id (string-ascii 36))
                                   (entity-id (string-ascii 36))
                                   (entity-type (string-ascii 32))
                                   (certification-type (string-ascii 64))
                                   (validity-period uint)
                                   (sustainability-score uint))
  (begin
    ;; Only authorized certifiers can issue
    (asserts! (or (is-eq tx-sender (var-get admin))
                 (is-authorized-certifier tx-sender))
             (err u403))

    ;; Score must be between 0 and 100
    (asserts! (<= sustainability-score u100) (err u400))

    ;; Record the certification
    (map-set certifications
      { certification-id: certification-id }
      {
        entity-id: entity-id,
        entity-type: entity-type,
        certification-type: certification-type,
        issued-at: block-height,
        expires-at: (+ block-height validity-period),
        issuer: tx-sender,
        status: "active",
        sustainability-score: sustainability-score
      }
    )

    (ok true)
  )
)

;; Authorized certifiers
(define-map authorized-certifiers
  { certifier: principal }
  { authorized: bool }
)

;; Check if a certifier is authorized
(define-read-only (is-authorized-certifier (certifier principal))
  (default-to false (get authorized (map-get? authorized-certifiers { certifier: certifier })))
)

;; Authorize a certifier
(define-public (authorize-certifier (certifier principal))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) (err u403))
    (map-set authorized-certifiers
      { certifier: certifier }
      { authorized: true }
    )
    (ok true)
  )
)

;; Revoke a certification
(define-public (revoke-certification (certification-id (string-ascii 36)))
  (let ((cert (unwrap! (map-get? certifications { certification-id: certification-id }) (err u404))))
    (begin
      ;; Only admin or the original issuer can revoke
      (asserts! (or (is-eq tx-sender (var-get admin))
                   (is-eq tx-sender (get issuer cert)))
               (err u403))

      ;; Update the certification status
      (map-set certifications
        { certification-id: certification-id }
        (merge cert { status: "revoked" })
      )

      (ok true)
    )
  )
)

;; Check if a certification is valid
(define-read-only (is-certification-valid (certification-id (string-ascii 36)))
  (let ((cert (map-get? certifications { certification-id: certification-id })))
    (and
      (is-some cert)
      (is-eq (get status (unwrap! cert false)) "active")
      (< block-height (get expires-at (unwrap! cert false)))
    )
  )
)

;; Get certification details
(define-read-only (get-certification (certification-id (string-ascii 36)))
  (map-get? certifications { certification-id: certification-id })
)

;; Set a new admin
(define-public (set-admin (new-admin principal))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) (err u403))
    (var-set admin new-admin)
    (ok true)
  )
)
