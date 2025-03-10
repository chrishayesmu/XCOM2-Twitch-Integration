class XComGameState_TwitchChatCommandTracking extends XComGameState_BaseObject
    dependson(TwitchChatCommand);

struct ChatCommandRecord {
    var string SenderLogin;        // Login of the viewer who used the command
    var name ChatCommandClassName; // Class name of the invoked chat command
    var int RealTimeUsed;          // Real time in seconds since level began play when the command was used (see WorldInfo.AudioTimeSeconds)
    var int TurnNumberWhenUsed;    // Turn number when the command was used
};

// Note: command history must always be stored such that commands which occurred first are closer to the 0 index of the array,
// and commands which occurred later are closer to the other end. This is relied on for some minor performance optimizations.
var private array<ChatCommandRecord> CommandHistory;

function bool IsChatCommandOnCooldown(TwitchChatCommand Command, string SenderLogin) {
    return !IsAllowedUnderLimits(Command.IndividualRateLimits, Command.Class.Name, SenderLogin, true)
        || !IsAllowedUnderLimits(Command.GlobalRateLimits,     Command.Class.Name, SenderLogin, false);
}

function RecordCommandUsage(TwitchChatCommand CommandInvoked, string SenderLogin) {
    local ChatCommandRecord Record;

    Record.SenderLogin = SenderLogin;
    Record.ChatCommandClassName = CommandInvoked.Class.Name;
    Record.RealTimeUsed = `XWORLDINFO.AudioTimeSeconds;
    Record.TurnNumberWhenUsed = class'X2TwitchUtils'.static.CalculateCurrentNaturalTurnNumber();

    CommandHistory.AddItem(Record);
}

protected function bool IsAllowedUnderLimits(ChatCommandRateLimitConfig LimitConfig, name ChatCommandClassName, string SenderLogin, bool IsIndividualConfig) {
    local int Index, CurrentTime, CurrentTurnNumber, ElapsedTurns, NumUsesThisTurn;
    local float ElapsedTime;

    if (LimitConfig.CooldownInSeconds > 0) {
        CurrentTime = `XWORLDINFO.AudioTimeSeconds;

        for (Index = CommandHistory.Length - 1; Index >= 0; Index--) {
            ElapsedTime = CurrentTime - CommandHistory[Index].RealTimeUsed;

            // If we reach any command which is older than our cooldown, then we know the cooldown doesn't apply
            if (ElapsedTime >= LimitConfig.CooldownInSeconds) {
                break;
            }

            if (CommandHistory[Index].ChatCommandClassName != ChatCommandClassName || (IsIndividualConfig && CommandHistory[Index].SenderLogin != SenderLogin)) {
                continue;
            }

            if (ElapsedTime < LimitConfig.CooldownInSeconds) {
                `TILOG("Viewer " $ SenderLogin $ " can't use chat command " $ ChatCommandClassName $ " because it's on cooldown for " $ (LimitConfig.CooldownInSeconds - ElapsedTime) $ " more seconds");
                return false;
            }
        }
    }

    CurrentTurnNumber = class'X2TwitchUtils'.static.CalculateCurrentNaturalTurnNumber();

    if (LimitConfig.CooldownInTurns > 0) {
        for (Index = CommandHistory.Length - 1; Index >= 0; Index--) {
            if (CommandHistory[Index].ChatCommandClassName != ChatCommandClassName || (IsIndividualConfig && CommandHistory[Index].SenderLogin != SenderLogin)) {
                continue;
            }

            ElapsedTurns = CurrentTurnNumber - CommandHistory[Index].TurnNumberWhenUsed;

            if (ElapsedTurns < LimitConfig.CooldownInTurns) {
                `TILOG("Viewer " $ SenderLogin $ " can't use chat command " $ ChatCommandClassName $ " because it's on cooldown for " $ (LimitConfig.CooldownInTurns - ElapsedTurns) $ " more turns");
                return false;
            }
        }
    }

    if (LimitConfig.MaxUsesPerTurn > 0) {
        for (Index = CommandHistory.Length - 1; Index >= 0; Index--) {
            if (CommandHistory[Index].ChatCommandClassName != ChatCommandClassName || (IsIndividualConfig && CommandHistory[Index].SenderLogin != SenderLogin)) {
                continue;
            }

            // If we iterate to a different turn number, then we've hit the end of the time period we're interested in
            if (CommandHistory[Index].TurnNumberWhenUsed != CurrentTurnNumber) {
                break;
            }

            NumUsesThisTurn++;

            if (NumUsesThisTurn >= LimitConfig.MaxUsesPerTurn) {
                `TILOG("Viewer " $ SenderLogin $ " can't use chat command " $ ChatCommandClassName $ " because it's on cooldown due to max uses this turn being reached");
                return false;
            }
        }
    }

    return true;
}

defaultproperties
{
    bSingletonStateType=true
    bTacticalTransient=true
}