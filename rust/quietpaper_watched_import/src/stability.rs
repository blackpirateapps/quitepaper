use crate::scan::Identity;
use std::time::{Duration, Instant};

pub struct Stability {
    pub identity: Identity,
    first: Instant,
    last: Instant,
    checks: u8,
}
impl Stability {
    pub fn new(identity: Identity, now: Instant) -> Self {
        Self {
            identity,
            first: now,
            last: now,
            checks: 1,
        }
    }
    pub fn observe(&mut self, identity: Identity, now: Instant) -> bool {
        if self.identity != identity {
            *self = Self::new(identity, now);
            return false;
        }
        if now.duration_since(self.last) >= Duration::from_secs(1) {
            self.checks = self.checks.saturating_add(1);
            self.last = now;
        }
        self.checks >= 3 && now.duration_since(self.first) >= Duration::from_secs(3)
    }
}
