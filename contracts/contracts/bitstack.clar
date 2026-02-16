;; @desc Platform fee distribution event for tracking marketplace revenue
;; @param event-id uint - Unique event identifier
;; @param fee-type (string-ascii 30) - Type of fee (dispute, creation, platform)
;; @param amount uint - Fee amount in micro-STX
;; @param from principal - Payer of the fee
;; @param purpose (string-ascii 200) - Purpose of the fee
;; @param distribution (list 5 {recipient: principal, amount: uint, reason: (string-ascii 50)}) - Fee distribution breakdown
(define-public (emit-platform-fee-event
        (fee-type (string-ascii 30))
        (amount uint)
        (from principal)
        (purpose (string-ascii 200))
        (distribution (list 5 {recipient: principal, amount: uint, reason: (string-ascii 50)}))
    )
    (let ((event-id (+ (var-get event-nonce) u1000000))) ;; Use separate event ID space
        ;; Validate fee amount
        (asserts! (> amount u0) ERR-ZERO-AMOUNT)
        
        ;; Validate fee type
        (asserts! (or 
            (is-eq fee-type "dispute")
            (is-eq fee-type "creation")
            (is-eq fee-type "platform")
            (is-eq fee-type "arbitration")
            (is-eq fee-type "withdrawal")
        ) ERR-INVALID-CATEGORY)
        
        ;; Validate distribution total matches amount
        (asserts! (is-eq (fold sum-distribution-amount distribution u0) amount) ERR-INVALID-AMOUNT)
        
        ;; Emit comprehensive event
        (print {
            event: "platform-fee-distributed",
            event-id: event-id,
            timestamp: stacks-block-height,
            fee-type: fee-type,
            total-amount: amount,
            payer: from,
            purpose: purpose,
            distribution: distribution,
            block-height: stacks-block-height,
            tx-sender: tx-sender
        })
        
        ;; Update platform statistics (optional - can be stored in a data map)
        (print {
            event: "platform-stats-updated",
            total-fees-collected: amount,
            fee-type: fee-type,
            running-total: amount ;; This would normally be accumulated in a data var
        })
        
        (ok event-id)
    )
)

;; @desc Helper function to sum distribution amounts
(define-private (sum-distribution-amount
        (dist {recipient: principal, amount: uint, reason: (string-ascii 50)})
        (total uint)
    )
    (+ total (get amount dist))
)

;; @desc Track platform fee statistics in a data map
(define-map PlatformFees
    { fee-type: (string-ascii 30) }
    {
        total-collected: uint,
        last-collected: uint,
        transaction-count: uint
    }
)

;; @desc Update platform fee statistics
(define-private (update-platform-fee-stats
        (fee-type (string-ascii 30))
        (amount uint)
    )
    (let ((current-stats (default-to 
            { total-collected: u0, last-collected: u0, transaction-count: u0 }
            (map-get? PlatformFees { fee-type: fee-type })
        )))
        (map-set PlatformFees { fee-type: fee-type }
            {
                total-collected: (+ (get total-collected current-stats) amount),
                last-collected: stacks-block-height,
                transaction-count: (+ (get transaction-count current-stats) u1)
            }
        )
        (ok true)
    )
)

;; @desc Get platform fee statistics
;; @param fee-type (string-ascii 30) - Type of fee to query
(define-read-only (get-platform-fee-stats (fee-type (string-ascii 30)))
    (default-to 
        { total-collected: u0, last-collected: u0, transaction-count: u0 }
        (map-get? PlatformFees { fee-type: fee-type })
    )
)

;; @desc Get all platform fee statistics
(define-read-only (get-all-platform-fee-stats)
    (ok {
        dispute: (get-platform-fee-stats "dispute"),
        creation: (get-platform-fee-stats "creation"),
        platform: (get-platform-fee-stats "platform"),
        arbitration: (get-platform-fee-stats "arbitration"),
        withdrawal: (get-platform-fee-stats "withdrawal"),
        total-all-fees: (+ 
            (get total-collected (get-platform-fee-stats "dispute"))
            (get total-collected (get-platform-fee-stats "creation"))
            (get total-collected (get-platform-fee-stats "platform"))
            (get total-collected (get-platform-fee-stats "arbitration"))
            (get total-collected (get-platform-fee-stats "withdrawal"))
        )
    })
)

;; @desc Enhanced dispute fee collection with platform fee event
(define-public (initiate-dispute-with-fee
        (task-id uint)
        (reason (string-ascii 256))
    )
    (let (
        (task (unwrap! (map-get? Tasks task-id) ERR-INVALID-ID))
        (dispute-id (+ (var-get dispute-nonce) u1))
        (dispute-fee (calculate-dispute-fee (get amount task)))
        (platform-cut (/ dispute-fee u10)) ;; 10% platform fee
        (arbitrator-potential (some (get-available-arbitrator))) ;; Get random arbitrator
    )
        ;; Check task doesn't already have a dispute
        (asserts! (is-none (get dispute-id task)) ERR-DISPUTE-EXISTS)
        
        ;; Check caller is creator or worker
        (asserts! (or 
            (is-eq tx-sender (get creator task))
            (is-eq (some tx-sender) (get worker task))
        ) ERR-NOT-DISPUTE-PARTICIPANT)
        
        ;; Check task is in valid state for dispute
        (asserts! (or 
            (is-eq (get status task) "in-progress")
            (is-eq (get status task) "submitted")
        ) ERR-NOT-IN-PROGRESS)
        
        ;; Charge dispute fee
        (try! (stx-transfer? dispute-fee tx-sender (as-contract tx-sender)))
        
        ;; Create dispute record
        (map-set Disputes dispute-id {
            task-id: task-id,
            initiator: tx-sender,
            reason: reason,
            arbitrator: none,
            resolution: none,
            created-at: stacks-block-height,
            resolved-at: none,
            winner: none,
            fee-paid: dispute-fee
        })
        
        ;; Update task status and link dispute
        (map-set Tasks task-id
            (merge task {
                status: "disputed",
                dispute-id: (some dispute-id)
            })
        )
        
        ;; Emit platform fee event for dispute fee
        (unwrap-panic (emit-platform-fee-event
            "dispute"
            dispute-fee
            tx-sender
            (concat (concat "Dispute fee for task #" (to-consensus-buff? task-id)) " - Initiated by user")
            (list 
                { recipient: (as-contract tx-sender), amount: (- dispute-fee platform-cut), reason: "dispute-escrow" }
                { recipient: (var-get contract-owner), amount: platform-cut, reason: "platform-fee" }
            )
        ))
        
        ;; Update platform fee statistics
        (unwrap-panic (update-platform-fee-stats "dispute" dispute-fee))
        
        ;; Increment dispute nonce
        (var-set dispute-nonce dispute-id)
        
        ;; Emit main event
        (print {
            event: "dispute-initiated-with-fee",
            task-id: task-id,
            dispute-id: dispute-id,
            initiator: tx-sender,
            reason: reason,
            fee-paid: dispute-fee,
            platform-fee: platform-cut,
            timestamp: stacks-block-height
        })
        
        (ok dispute-id)
    )
)

;; @desc Get available arbitrator (simplified - would normally rotate or select based on workload)
(define-private (get-available-arbitrator)
    (some (var-get contract-owner)) ;; Fallback to contract owner
)

;; @desc Enhanced task creation with platform fee
(define-public (create-task-with-platform-fee
        (title (string-ascii 100))
        (description (string-ascii 500))
        (amount uint)
        (deadline uint)
        (category (string-ascii 30))
    )
    (let (
        (task-id (+ (var-get task-nonce) u1))
        (creation-fee (/ amount u100)) ;; 1% creation fee
        (platform-cut (/ creation-fee u5)) ;; 20% of creation fee
    )
        ;; Validate task parameters
        (try! (validate-task-creation title description amount deadline category))

        ;; Transfer total STX from creator to contract (task amount + creation fee)
        (try! (stx-transfer? (+ amount creation-fee) tx-sender (as-contract tx-sender)))

        ;; Store task data
        (map-set Tasks task-id {
            title: title,
            description: description,
            creator: tx-sender,
            worker: none,
            amount: amount,
            deadline: deadline,
            status: "open",
            submission: none,
            created-at: stacks-block-height,
            category: category,
            dispute-id: none,
            rating: none,
            milestone-count: u0,
            escrow-remaining: amount,
            revision-count: u0,
            submission-count: u0,
        })

        ;; Update category statistics
        (try! (increment-category-count category))

        ;; Emit platform fee event for creation fee
        (unwrap-panic (emit-platform-fee-event
            "creation"
            creation-fee
            tx-sender
            (concat (concat "Creation fee for task #" (to-consensus-buff? task-id)) " - Platform listing fee")
            (list 
                { recipient: (as-contract tx-sender), amount: (- creation-fee platform-cut), reason: "task-escrow" }
                { recipient: (var-get contract-owner), amount: platform-cut, reason: "platform-fee" }
            )
        ))

        ;; Update platform fee statistics
        (unwrap-panic (update-platform-fee-stats "creation" creation-fee))

        ;; Increment nonce
        (var-set task-nonce task-id)

        ;; Emit event
        (print {
            event: "created-with-fee",
            id: task-id,
            creator: tx-sender,
            amount: amount,
            creation-fee: creation-fee,
            deadline: deadline,
            category: category,
        })

        (ok task-id)
    )
)
