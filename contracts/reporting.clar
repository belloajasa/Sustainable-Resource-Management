;; Reporting Contract
;; Generates authenticated sustainability disclosures

(define-data-var admin principal tx-sender)

;; Report data structure
(define-map reports
  { report-id: (string-ascii 36) }
  {
    entity-id: (string-ascii 36),
    report-type: (string-ascii 32), ;; "sustainability", "compliance", "audit"
    period-start: uint,
    period-end: uint,
    created-at: uint,
    created-by: principal,
    hash: (buff 32), ;; Hash of the report content
    status: (string-ascii 16), ;; "draft", "published", "verified"
    verifier: (optional principal)
  }
)

;; Create a new report
(define-public (create-report (report-id (string-ascii 36))
                             (entity-id (string-ascii 36))
                             (report-type (string-ascii 32))
                             (period-start uint)
                             (period-end uint)
                             (report-hash (buff 32)))
  (begin
    ;; Only authorized reporters can create
    (asserts! (or (is-eq tx-sender (var-get admin))
                 (is-authorized-reporter tx-sender))
             (err u403))

    ;; Record the report
    (map-set reports
      { report-id: report-id }
      {
        entity-id: entity-id,
        report-type: report-type,
        period-start: period-start,
        period-end: period-end,
        created-at: block-height,
        created-by: tx-sender,
        hash: report-hash,
        status: "draft",
        verifier: none
      }
    )

    (ok true)
  )
)

;; Publish a report
(define-public (publish-report (report-id (string-ascii 36)))
  (let ((report (unwrap! (map-get? reports { report-id: report-id }) (err u404))))
    (begin
      ;; Only admin or the creator can publish
      (asserts! (or (is-eq tx-sender (var-get admin))
                   (is-eq tx-sender (get created-by report)))
               (err u403))

      ;; Update the report status
      (map-set reports
        { report-id: report-id }
        (merge report { status: "published" })
      )

      (ok true)
    )
  )
)

;; Verify a report
(define-public (verify-report (report-id (string-ascii 36)))
  (let ((report (unwrap! (map-get? reports { report-id: report-id }) (err u404))))
    (begin
      ;; Only authorized verifiers can verify
      (asserts! (is-authorized-verifier tx-sender) (err u403))

      ;; Report must be published
      (asserts! (is-eq (get status report) "published") (err u400))

      ;; Update the report status
      (map-set reports
        { report-id: report-id }
        (merge report {
          status: "verified",
          verifier: (some tx-sender)
        })
      )

      (ok true)
    )
  )
)

;; Authorized reporters
(define-map authorized-reporters
  { reporter: principal }
  { authorized: bool }
)

;; Authorized verifiers
(define-map authorized-verifiers
  { verifier: principal }
  { authorized: bool }
)

;; Check if a reporter is authorized
(define-read-only (is-authorized-reporter (reporter principal))
  (default-to false (get authorized (map-get? authorized-reporters { reporter: reporter })))
)

;; Check if a verifier is authorized
(define-read-only (is-authorized-verifier (verifier principal))
  (default-to false (get authorized (map-get? authorized-verifiers { verifier: verifier })))
)

;; Authorize a reporter
(define-public (authorize-reporter (reporter principal))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) (err u403))
    (map-set authorized-reporters
      { reporter: reporter }
      { authorized: true }
    )
    (ok true)
  )
)

;; Authorize a verifier
(define-public (authorize-verifier (verifier principal))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) (err u403))
    (map-set authorized-verifiers
      { verifier: verifier }
      { authorized: true }
    )
    (ok true)
  )
)

;; Get report details
(define-read-only (get-report (report-id (string-ascii 36)))
  (map-get? reports { report-id: report-id })
)

;; Set a new admin
(define-public (set-admin (new-admin principal))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) (err u403))
    (var-set admin new-admin)
    (ok true)
  )
)
