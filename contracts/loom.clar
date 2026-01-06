
(define-constant ERR-NOT-AUTH u401)
(define-constant ERR-NOT-FOUND u404)
(define-constant ERR-ALREADY-COMMITTED u409)
(define-constant ERR-NOT-READY u412)
(define-constant ERR-BAD-COMMIT u400)
(define-constant ERR-EMPTY-POOL u422)
(define-constant ERR-BAD-CONFIG u422)

(define-constant ROLL-MOD u10000)
(define-constant TIER-COMMON u0)
(define-constant TIER-RARE u1)
(define-constant TIER-LEGENDARY u2)

(define-data-var owner principal 'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM)

(define-data-var common-max uint u8999)
(define-data-var rare-max uint u9799)
(define-data-var legendary-max uint u9999)

(define-data-var common-items (list 50 uint) (list u100 u101 u102 u103))
(define-data-var rare-items (list 50 uint) (list u200 u201 u202))
(define-data-var legendary-items (list 50 uint) (list u300 u301))

(define-map commitments {player: principal} {commit: (buff 32), target-height: uint})

(define-private (is-owner (sender principal))
    (is-eq sender (var-get owner))
)

(define-private (hash->uint (hash (buff 32)))
    (let ((slice (unwrap-panic (slice? hash u0 u16))))
        (buff-to-uint-be (unwrap-panic (as-max-len? slice u16)))
    )
)

(define-private (derive-seed (entropy (buff 32)) (secret (buff 32)))
    (hash->uint (sha256 (concat entropy secret)))
)

(define-private (roll->tier (roll uint))
    (if (<= roll (var-get common-max))
        TIER-COMMON
        (if (<= roll (var-get rare-max))
            TIER-RARE
            TIER-LEGENDARY))
)

(define-private (items-for-tier (tier uint))
    (if (is-eq tier TIER-LEGENDARY)
        (var-get legendary-items)
        (if (is-eq tier TIER-RARE)
            (var-get rare-items)
            (var-get common-items)))
)

(define-private (select-item (items (list 50 uint)) (seed uint))
    (unwrap-panic (element-at? items (mod seed (len items))))
)

(define-public (set-owner (new-owner principal))
    (begin
        (asserts! (is-owner tx-sender) (err ERR-NOT-AUTH))
        (var-set owner new-owner)
        (ok new-owner)
    )
)

(define-public (set-thresholds (new-common-max uint) (new-rare-max uint) (new-legendary-max uint))
    (begin
        (asserts! (is-owner tx-sender) (err ERR-NOT-AUTH))
        (asserts! (< new-common-max new-rare-max) (err ERR-BAD-CONFIG))
        (asserts! (< new-rare-max new-legendary-max) (err ERR-BAD-CONFIG))
        (asserts! (is-eq new-legendary-max (- ROLL-MOD u1)) (err ERR-BAD-CONFIG))
        (var-set common-max new-common-max)
        (var-set rare-max new-rare-max)
        (var-set legendary-max new-legendary-max)
        (ok true)
    )
)

(define-public (set-common-items (items (list 50 uint)))
    (begin
        (asserts! (is-owner tx-sender) (err ERR-NOT-AUTH))
        (asserts! (> (len items) u0) (err ERR-EMPTY-POOL))
        (var-set common-items items)
        (ok (len items))
    )
)

(define-public (set-rare-items (items (list 50 uint)))
    (begin
        (asserts! (is-owner tx-sender) (err ERR-NOT-AUTH))
        (asserts! (> (len items) u0) (err ERR-EMPTY-POOL))
        (var-set rare-items items)
        (ok (len items))
    )
)

(define-public (set-legendary-items (items (list 50 uint)))
    (begin
        (asserts! (is-owner tx-sender) (err ERR-NOT-AUTH))
        (asserts! (> (len items) u0) (err ERR-EMPTY-POOL))
        (var-set legendary-items items)
        (ok (len items))
    )
)

(define-public (open-box (commit (buff 32)))
    (let ((existing (map-get? commitments {player: tx-sender}))
          (target-height (+ burn-block-height u1)))
        (asserts! (is-none existing) (err ERR-ALREADY-COMMITTED))
        (map-set commitments {player: tx-sender} {commit: commit, target-height: target-height})
        (ok {target-height: target-height})
    )
)

(define-public (reveal-box (secret (buff 32)))
    (let ((entry (unwrap! (map-get? commitments {player: tx-sender}) (err ERR-NOT-FOUND))))
        (asserts! (>= burn-block-height (get target-height entry)) (err ERR-NOT-READY))
        (asserts! (is-eq (sha256 secret) (get commit entry)) (err ERR-BAD-COMMIT))
        (let ((entropy (unwrap! (get-burn-block-info? header-hash (get target-height entry)) (err ERR-NOT-FOUND)))
              (seed (derive-seed entropy secret))
              (roll (mod seed ROLL-MOD))
              (tier (roll->tier roll))
              (items (items-for-tier tier))
              (item-count (len items)))
            (asserts! (> item-count u0) (err ERR-EMPTY-POOL))
            (map-delete commitments {player: tx-sender})
            (ok {
                roll: roll,
                tier: tier,
                item-id: (select-item items seed),
                target-height: (get target-height entry)
            })
        )
    )
)
