;; BitStack NFT - Task Completion Rewards
;; SIP-009 compliant NFT minted as proof of task completion

(impl-trait 'SP2PABAF9FTAJYNFZH93XENAJ8FVY99RRM50D2JG9.nft-trait.nft-trait)

(define-non-fungible-token bitstack-nft uint)

(define-data-var last-token-id uint u0)
(define-data-var base-uri (string-ascii 256) "https://bitstack.io/nft/")

(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-not-token-owner (err u101))
(define-constant err-invalid-task (err u102))
(define-constant err-unauthorized (err u103))

;; Map token to task metadata
(define-map token-metadata uint {
  task-id: uint,
  worker: principal,
  completed-at: uint,
  reward-amount: uint
})

;; SIP-009 Functions

(define-read-only (get-last-token-id)
  (ok (var-get last-token-id)))

(define-read-only (get-token-uri (token-id uint))
  (ok (some (concat (var-get base-uri) (uint-to-ascii token-id)))))

(define-read-only (get-owner (token-id uint))
  (ok (nft-get-owner? bitstack-nft token-id)))

(define-public (transfer (token-id uint) (sender principal) (recipient principal))
  (begin
    (asserts! (is-eq tx-sender sender) err-not-token-owner)
    (nft-transfer? bitstack-nft token-id sender recipient)))

;; Extended Functions

(define-read-only (get-token-metadata (token-id uint))
  (map-get? token-metadata token-id))

(define-public (mint-for-task (recipient principal) (task-id uint) (reward-amount uint))
  (let ((token-id (+ (var-get last-token-id) u1)))
    (try! (nft-mint? bitstack-nft token-id recipient))
    (map-set token-metadata token-id {
      task-id: task-id,
      worker: recipient,
      completed-at: block-height,
      reward-amount: reward-amount
    })
    (var-set last-token-id token-id)
    (ok token-id)))

(define-public (set-base-uri (new-uri (string-ascii 256)))
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (ok (var-set base-uri new-uri))))

;; Helper function to convert uint to ascii
(define-private (uint-to-ascii (value uint))
  (if (<= value u9)
    (unwrap-panic (element-at "0123456789" value))
    (concat 
      (uint-to-ascii (/ value u10))
      (unwrap-panic (element-at "0123456789" (mod value u10))))))
