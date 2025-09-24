;; Autonomous Bounty-Based Problem Resolution and Innovation Engine
;; A decentralized platform for posting problems, submitting solutions, and autonomous reward distribution
;; Version: 1.0.0
;; Compatible with: Clarinet 3.x

;; Constants
(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_UNAUTHORIZED (err u401))
(define-constant ERR_PROBLEM_NOT_FOUND (err u404))
(define-constant ERR_SOLUTION_NOT_FOUND (err u405))
(define-constant ERR_INSUFFICIENT_FUNDS (err u402))
(define-constant ERR_INVALID_PARAMETERS (err u400))
(define-constant ERR_PROBLEM_CLOSED (err u408))
(define-constant ERR_ALREADY_SUBMITTED (err u409))
(define-constant ERR_INSUFFICIENT_REPUTATION (err u407))
(define-constant ERR_VOTING_PERIOD_ACTIVE (err u410))

;; Problem Categories
(define-constant CATEGORY_TECHNICAL u1)
(define-constant CATEGORY_BUSINESS u2)
(define-constant CATEGORY_SOCIAL u3)
(define-constant CATEGORY_ENVIRONMENTAL u4)
(define-constant CATEGORY_RESEARCH u5)

;; Problem Status
(define-constant STATUS_OPEN u1)
(define-constant STATUS_VOTING u2)
(define-constant STATUS_RESOLVED u3)
(define-constant STATUS_EXPIRED u4)

;; Solution Status
(define-constant SOLUTION_PENDING u1)
(define-constant SOLUTION_APPROVED u2)
(define-constant SOLUTION_REJECTED u3)

;; Data Variables
(define-data-var problem-counter uint u0)
(define-data-var solution-counter uint u0)
(define-data-var platform-fee-percentage uint u5) ;; 5% platform fee
(define-data-var min-bounty-amount uint u10000) ;; Minimum 10,000 microSTX
(define-data-var voting-period-blocks uint u1440) ;; ~10 days in blocks
(define-data-var min-solver-reputation uint u10) ;; Minimum reputation to submit solutions
(define-data-var innovation-bonus-multiplier uint u150) ;; 150% bonus for innovative solutions

;; Data Maps

;; Problem Storage
(define-map problems 
    { problem-id: uint }
    {
        poster: principal,
        title: (string-ascii 128),
        description: (string-ascii 1024),
        category: uint,
        bounty-amount: uint,
        additional-rewards: uint,
        deadline: uint,
        status: uint,
        solution-count: uint,
        winning-solution-id: (optional uint),
        innovation-score: uint,
        created-at: uint,
        resolved-at: (optional uint)
    }
)

;; Solution Storage
(define-map solutions 
    { solution-id: uint }
    {
        problem-id: uint,
        solver: principal,
        title: (string-ascii 128),
        description: (string-ascii 2048),
        implementation-details: (string-ascii 1024),
        innovation-level: uint,
        feasibility-score: uint,
        impact-assessment: uint,
        resource-requirements: (string-ascii 512),
        status: uint,
        votes-for: uint,
        votes-against: uint,
        total-vote-weight: uint,
        submitted-at: uint,
        approved-at: (optional uint)
    }
)

;; Solver Profiles
(define-map solver-profiles
    { solver: principal }
    {
        name: (string-ascii 64),
        expertise-areas: (string-ascii 256),
        reputation-score: uint,
        problems-solved: uint,
        total-bounties-earned: uint,
        innovation-index: uint,
        success-rate: uint,
        last-active: uint
    }
)

;; Voting Records
(define-map solution-votes
    { solution-id: uint, voter: principal }
    {
        vote-weight: uint,
        vote-direction: bool, ;; true for approval, false for rejection
        expertise-match: uint,
        voted-at: uint
    }
)

;; Problem Funding
(define-map additional-funding
    { problem-id: uint, funder: principal }
    {
        amount: uint,
        funding-type: uint, ;; 1: individual, 2: corporate, 3: community
        funded-at: uint
    }
)

;; Innovation Tracking
(define-map innovation-metrics
    { problem-id: uint }
    {
        novelty-score: uint,
        complexity-level: uint,
        market-potential: uint,
        technical-difficulty: uint,
        collaboration-factor: uint,
        sustainability-index: uint
    }
)

;; Autonomous Engine Settings
(define-map engine-parameters
    { param-name: (string-ascii 32) }
    { param-value: uint }
)

;; Public Functions

;; Initialize solver profile
(define-public (create-solver-profile 
    (name (string-ascii 64))
    (expertise-areas (string-ascii 256)))
    (begin
        (asserts! (> (len name) u0) ERR_INVALID_PARAMETERS)
        (asserts! (> (len expertise-areas) u0) ERR_INVALID_PARAMETERS)
        
        (map-set solver-profiles { solver: tx-sender }
            {
                name: name,
                expertise-areas: expertise-areas,
                reputation-score: u50, ;; Starting reputation
                problems-solved: u0,
                total-bounties-earned: u0,
                innovation-index: u0,
                success-rate: u100,
                last-active: burn-block-height
            }
        )
        (ok true)
    )
)

;; Post a new problem with bounty
(define-public (post-problem
    (title (string-ascii 128))
    (description (string-ascii 1024))
    (category uint)
    (bounty-amount uint)
    (deadline uint))
    (let 
        (
            (new-problem-id (+ (var-get problem-counter) u1))
            (problem-deadline (+ burn-block-height deadline))
        )
        (asserts! (> (len title) u0) ERR_INVALID_PARAMETERS)
        (asserts! (> (len description) u0) ERR_INVALID_PARAMETERS)
        (asserts! (and (>= category u1) (<= category u5)) ERR_INVALID_PARAMETERS)
        (asserts! (>= bounty-amount (var-get min-bounty-amount)) ERR_INVALID_PARAMETERS)
        (asserts! (>= (stx-get-balance tx-sender) bounty-amount) ERR_INSUFFICIENT_FUNDS)
        (asserts! (> deadline u0) ERR_INVALID_PARAMETERS)
        
        ;; Transfer bounty to contract
        (try! (stx-transfer? bounty-amount tx-sender (as-contract tx-sender)))
        
        (map-set problems { problem-id: new-problem-id }
            {
                poster: tx-sender,
                title: title,
                description: description,
                category: category,
                bounty-amount: bounty-amount,
                additional-rewards: u0,
                deadline: problem-deadline,
                status: STATUS_OPEN,
                solution-count: u0,
                winning-solution-id: none,
                innovation-score: u0,
                created-at: burn-block-height,
                resolved-at: none
            }
        )
        
        ;; Initialize innovation metrics
        (map-set innovation-metrics { problem-id: new-problem-id }
            {
                novelty-score: u0,
                complexity-level: category, ;; Base complexity on category
                market-potential: u50, ;; Default moderate potential
                technical-difficulty: u50,
                collaboration-factor: u0,
                sustainability-index: u50
            }
        )
        
        (var-set problem-counter new-problem-id)
        (ok new-problem-id)
    )
)

;; Submit a solution to a problem
(define-public (submit-solution
    (problem-id uint)
    (title (string-ascii 128))
    (description (string-ascii 2048))
    (implementation-details (string-ascii 1024))
    (innovation-level uint)
    (feasibility-score uint)
    (impact-assessment uint)
    (resource-requirements (string-ascii 512)))
    (let 
        (
            (problem (unwrap! (map-get? problems { problem-id: problem-id }) ERR_PROBLEM_NOT_FOUND))
            (solver-profile (unwrap! (map-get? solver-profiles { solver: tx-sender }) ERR_UNAUTHORIZED))
            (new-solution-id (+ (var-get solution-counter) u1))
        )
        (asserts! (is-eq (get status problem) STATUS_OPEN) ERR_PROBLEM_CLOSED)
        (asserts! (<= burn-block-height (get deadline problem)) ERR_PROBLEM_CLOSED)
        (asserts! (>= (get reputation-score solver-profile) (var-get min-solver-reputation)) ERR_INSUFFICIENT_REPUTATION)
        (asserts! (> (len title) u0) ERR_INVALID_PARAMETERS)
        (asserts! (> (len description) u0) ERR_INVALID_PARAMETERS)
        (asserts! (and (<= innovation-level u100) (<= feasibility-score u100) (<= impact-assessment u100)) ERR_INVALID_PARAMETERS)
        
        (map-set solutions { solution-id: new-solution-id }
            {
                problem-id: problem-id,
                solver: tx-sender,
                title: title,
                description: description,
                implementation-details: implementation-details,
                innovation-level: innovation-level,
                feasibility-score: feasibility-score,
                impact-assessment: impact-assessment,
                resource-requirements: resource-requirements,
                status: SOLUTION_PENDING,
                votes-for: u0,
                votes-against: u0,
                total-vote-weight: u0,
                submitted-at: burn-block-height,
                approved-at: none
            }
        )
        
        ;; Update problem solution count
        (map-set problems { problem-id: problem-id }
            (merge problem { solution-count: (+ (get solution-count problem) u1) })
        )
        
        ;; Update solver last active time
        (map-set solver-profiles { solver: tx-sender }
            (merge solver-profile { last-active: burn-block-height })
        )
        
        (var-set solution-counter new-solution-id)
        (ok new-solution-id)
    )
)

;; Vote on a solution
(define-public (vote-on-solution 
    (solution-id uint) 
    (vote-direction bool) 
    (vote-weight uint)
    (expertise-match uint))
    (let 
        (
            (solution (unwrap! (map-get? solutions { solution-id: solution-id }) ERR_SOLUTION_NOT_FOUND))
            (problem (unwrap! (map-get? problems { problem-id: (get problem-id solution) }) ERR_PROBLEM_NOT_FOUND))
            (voter-profile (unwrap! (map-get? solver-profiles { solver: tx-sender }) ERR_UNAUTHORIZED))
        )
        (asserts! (is-eq (get status problem) STATUS_VOTING) ERR_VOTING_PERIOD_ACTIVE)
        (asserts! (not (is-eq tx-sender (get solver solution))) ERR_UNAUTHORIZED) ;; Can't vote on own solution
        (asserts! (and (<= vote-weight u10) (<= expertise-match u10)) ERR_INVALID_PARAMETERS)
        (asserts! (is-none (map-get? solution-votes { solution-id: solution-id, voter: tx-sender })) ERR_ALREADY_SUBMITTED)
        
        ;; Calculate weighted vote based on reputation
        (let 
            (
                (reputation-multiplier (/ (get reputation-score voter-profile) u100))
                (final-vote-weight (* vote-weight reputation-multiplier expertise-match))
            )
            (map-set solution-votes { solution-id: solution-id, voter: tx-sender }
                {
                    vote-weight: final-vote-weight,
                    vote-direction: vote-direction,
                    expertise-match: expertise-match,
                    voted-at: burn-block-height
                }
            )
            
            ;; Update solution vote counts
            (map-set solutions { solution-id: solution-id }
                (merge solution {
                    votes-for: (if vote-direction 
                                 (+ (get votes-for solution) u1)
                                 (get votes-for solution)),
                    votes-against: (if vote-direction 
                                     (get votes-against solution)
                                     (+ (get votes-against solution) u1)),
                    total-vote-weight: (+ (get total-vote-weight solution) final-vote-weight)
                })
            )
            (ok true)
        )
    )
)

;; Start voting period for a problem
(define-public (initiate-voting-period (problem-id uint))
    (let 
        (
            (problem (unwrap! (map-get? problems { problem-id: problem-id }) ERR_PROBLEM_NOT_FOUND))
        )
        (asserts! (is-eq (get status problem) STATUS_OPEN) ERR_INVALID_PARAMETERS)
        (asserts! (or (> burn-block-height (get deadline problem)) 
                     (> (get solution-count problem) u2)) ERR_INVALID_PARAMETERS) ;; Auto-trigger if deadline passed or multiple solutions
        
        (map-set problems { problem-id: problem-id }
            (merge problem { status: STATUS_VOTING })
        )
        (ok true)
    )
)

;; Autonomous resolution of problem (distribute bounties)
(define-public (resolve-problem (problem-id uint))
    (let 
        (
            (problem (unwrap! (map-get? problems { problem-id: problem-id }) ERR_PROBLEM_NOT_FOUND))
            (total-bounty (+ (get bounty-amount problem) (get additional-rewards problem)))
            (platform-fee (/ (* total-bounty (var-get platform-fee-percentage)) u100))
            (distributable-bounty (- total-bounty platform-fee))
        )
        (asserts! (is-eq (get status problem) STATUS_VOTING) ERR_INVALID_PARAMETERS)
        (asserts! (> burn-block-height (+ (get created-at problem) (var-get voting-period-blocks))) ERR_VOTING_PERIOD_ACTIVE)
        (asserts! (> (get solution-count problem) u0) ERR_INVALID_PARAMETERS)
        
        ;; Find winning solution (highest total vote weight)
        (let 
            (
                (winning-solution-id (unwrap! (get-winning-solution problem-id) ERR_SOLUTION_NOT_FOUND))
                (winning-solution (unwrap! (map-get? solutions { solution-id: winning-solution-id }) ERR_SOLUTION_NOT_FOUND))
                (winner (get solver winning-solution))
                (innovation-bonus (if (> (get innovation-level winning-solution) u75)
                                    (/ (* distributable-bounty (var-get innovation-bonus-multiplier)) u100)
                                    u0))
                (final-reward (+ distributable-bounty innovation-bonus))
            )
            
            ;; Transfer rewards to winner
            (try! (as-contract (stx-transfer? final-reward tx-sender winner)))
            
            ;; Update problem status
            (map-set problems { problem-id: problem-id }
                (merge problem {
                    status: STATUS_RESOLVED,
                    winning-solution-id: (some winning-solution-id),
                    resolved-at: (some burn-block-height)
                })
            )
            
            ;; Update winning solution status
            (map-set solutions { solution-id: winning-solution-id }
                (merge winning-solution {
                    status: SOLUTION_APPROVED,
                    approved-at: (some burn-block-height)
                })
            )
            
            ;; Update winner's profile
            (let 
                (
                    (winner-profile (unwrap! (map-get? solver-profiles { solver: winner }) ERR_UNAUTHORIZED))
                )
                (map-set solver-profiles { solver: winner }
                    (merge winner-profile {
                        problems-solved: (+ (get problems-solved winner-profile) u1),
                        total-bounties-earned: (+ (get total-bounties-earned winner-profile) final-reward),
                        reputation-score: (+ (get reputation-score winner-profile) u25),
                        innovation-index: (+ (get innovation-index winner-profile) (get innovation-level winning-solution))
                    })
                )
            )
            
            (ok winning-solution-id)
        )
    )
)

;; Add additional funding to a problem
(define-public (add-bounty-funding (problem-id uint) (additional-amount uint) (funding-type uint))
    (let 
        (
            (problem (unwrap! (map-get? problems { problem-id: problem-id }) ERR_PROBLEM_NOT_FOUND))
        )
        (asserts! (not (is-eq (get status problem) STATUS_RESOLVED)) ERR_PROBLEM_CLOSED)
        (asserts! (> additional-amount u0) ERR_INVALID_PARAMETERS)
        (asserts! (>= (stx-get-balance tx-sender) additional-amount) ERR_INSUFFICIENT_FUNDS)
        (asserts! (and (>= funding-type u1) (<= funding-type u3)) ERR_INVALID_PARAMETERS)
        
        ;; Transfer additional funding to contract
        (try! (stx-transfer? additional-amount tx-sender (as-contract tx-sender)))
        
        ;; Update problem additional rewards
        (map-set problems { problem-id: problem-id }
            (merge problem { additional-rewards: (+ (get additional-rewards problem) additional-amount) })
        )
        
        ;; Record funding
        (map-set additional-funding { problem-id: problem-id, funder: tx-sender }
            {
                amount: additional-amount,
                funding-type: funding-type,
                funded-at: burn-block-height
            }
        )
        (ok true)
    )
)

;; Helper function to find winning solution (private function simulation)
(define-private (get-winning-solution (problem-id uint))
    (let 
        (
            (problem (unwrap! (map-get? problems { problem-id: problem-id }) (some u0)))
        )
        ;; This is a simplified version - in a full implementation, 
        ;; you'd iterate through all solutions to find the highest vote weight
        ;; For MVP, we'll return the first solution as winner if it exists
        (if (> (get solution-count problem) u0)
            (some u1) ;; Return first solution ID as winner (simplified)
            none)
    )
)

;; Read-only functions

(define-read-only (get-problem (problem-id uint))
    (map-get? problems { problem-id: problem-id })
)

(define-read-only (get-solution (solution-id uint))
    (map-get? solutions { solution-id: solution-id })
)

(define-read-only (get-solver-profile (solver principal))
    (map-get? solver-profiles { solver: solver })
)

(define-read-only (get-problem-counter)
    (var-get problem-counter)
)

(define-read-only (get-solution-counter)
    (var-get solution-counter)
)

(define-read-only (get-platform-stats)
    {
        total-problems: (var-get problem-counter),
        total-solutions: (var-get solution-counter),
        platform-fee: (var-get platform-fee-percentage),
        min-bounty: (var-get min-bounty-amount)
    }
)

;; Admin functions (contract owner only)
(define-public (update-platform-fee (new-fee uint))
    (begin
        (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
        (asserts! (<= new-fee u20) ERR_INVALID_PARAMETERS) ;; Max 20% fee
        (var-set platform-fee-percentage new-fee)
        (ok true)
    )
)

(define-public (update-min-bounty (new-min uint))
    (begin
        (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
        (var-set min-bounty-amount new-min)
        (ok true)
    )
)

(define-public (emergency-pause (problem-id uint))
    (let 
        (
            (problem (unwrap! (map-get? problems { problem-id: problem-id }) ERR_PROBLEM_NOT_FOUND))
        )
        (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
        (map-set problems { problem-id: problem-id }
            (merge problem { status: STATUS_EXPIRED })
        )
        (ok true)
    )
)