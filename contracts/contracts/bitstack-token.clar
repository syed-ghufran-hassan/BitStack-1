;; BitStack Token (BST)
;; SIP-010 Fungible Token Standard Implementation
;; Provides core token functionality for the BitStack ecosystem

(define-fungible-token bitstack-token u100000000000000)

;; Error codes
(define-constant ERR-UNAUTHORIZED (err u100))
(define-constant ERR-INSUFFICIENT-BALANCE (err u101))
(define-constant ERR-INVALID-AMOUNT (err u102))

(define-data-var token-uri (optional (string-utf8 256)) none)

;; Read-only functions
(define-read-only (get-name)
  (ok "BitStack Token"))

(define-read-only (get-symbol)
  (ok "BST"))

(define-read-only (get-decimals)
  (ok u6))

(define-read-only (get-balance (account principal))
  (ok (ft-get-balance bitstack-token account)))

(define-read-only (get-total-supply)
  (ok (ft-get-supply bitstack-token)))

(define-read-only (get-token-uri)
  (ok (var-get token-uri)))

(define-public (transfer (amount uint) (sender principal) (recipient principal) (memo (optional (buff 34))))
  (begin
    (asserts! (is-eq tx-sender sender) ERR-UNAUTHORIZED)
    (asserts! (> amount u0) ERR-INVALID-AMOUNT)
    (try! (ft-transfer? bitstack-token amount sender recipient))
    (match memo to-print (print to-print) 0x)
    (ok true)))

(define-public (mint (amount uint) (recipient principal))
  (begin
    (asserts! (is-eq tx-sender contract-caller) ERR-UNAUTHORIZED)
    (asserts! (> amount u0) ERR-INVALID-AMOUNT)
    (ft-mint? bitstack-token amount recipient)))

(define-public (burn (amount uint) (sender principal))
  (begin
    (asserts! (is-eq tx-sender sender) ERR-UNAUTHORIZED)
    (asserts! (> amount u0) ERR-INVALID-AMOUNT)
    (ft-burn? bitstack-token amount sender)))

(define-public (set-token-uri (uri (string-utf8 256)))
  (begin
    (asserts! (is-eq tx-sender contract-caller) ERR-UNAUTHORIZED)
    (ok (var-set token-uri (some uri)))))

(begin
  (try! (ft-mint? bitstack-token u100000000000000 tx-sender))
  (ok true))
