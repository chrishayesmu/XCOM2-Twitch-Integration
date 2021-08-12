class TwitchCommandHandler_Vote extends TwitchCommandHandler;

function Handle(TwitchStateManager StateMgr, TwitchMessage Command, TwitchViewer Viewer) {
	local int VoteChoiceIndex;

	// Invalid commands like "vote! xyz" will be cast to 0, then -1 will be sent in,
	// causing them to be rejected for an invalid index. For valid commands this just
	// maps from the on-screen [1, 2, .. n] to a 0-based index.
	VoteChoiceIndex = int(GetCommandBody(Command)) - 1;

	StateMgr.CastVote(Viewer, VoteChoiceIndex);
}