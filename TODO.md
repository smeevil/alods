# TODO

- [ ] Store successful deliveries in its own DETS table
- [ ] Store last server response with failures ?
- [ ] List pending
- [ ] List pending with errors
- [ ] List successes
- [ ] Battle test the GenServer / Supervisors
- [ ] Document every module
- [ ] Document every public call
- [ ] Cleanup code
- [x] Set max timeout of deliver to one hour, keep retrying every hour
- [ ] Set max days of deliveries retries a week, configurable

## YAGNI?
- [ ] HTTP Basic auth
- [ ] application/x-www-form-urlencoded POST
- [ ] Option to switch between JSON or Form for POST
- [ ] Optional header enrichment for Bearer tokens
- [ ] Add interface to show queues and successes
