# Map synchronization evidence

`LatestWinsMapSynchronizer` permits exactly one asynchronous map mutation at a
time and collapses queued poll updates to the newest pending snapshot. Unit
tests prove no overlap, latest-wins ordering, and recovery after failure. Driver
map updates keep stable marker/layer identities and preserve the last usable
map when image, annotation, line, or camera work fails.

The real-browser run held the Driver workspace across repeated two-second polls,
locale navigation, route preparation, route replacement, and moving position
updates. The map stayed rendered; final Driver and Owner screenshots contain
the active approach route and trail rather than an unavailable fallback.
