

This is a Markdown file. You can use any free online Markdown viewer for easier reading.


# Overview

This mod is intended as a highly configurable experience. In fact, it's expected that the out-of-the-box experience isn't going to be ideal for almost anyone, because streaming and chat interaction are so highly individualized. Which options make the most sense for your stream is something you'll have to work out based on your community, and probably some healthy trial-and-error.

## Config files

Some of this can be configured in-game using ModConfigMenu, but it will always be necessary to do a lot of the more nitty-gritty configuration in the ini files directly.

* `XComTwitchIntegration.ini` - Start here. This is where you specify your channel name and some high-level configuration around raffling.
* `XComTwitchActions.ini` - Contains definitions of different Actions, which are the building blocks of chat commands and poll events.
* `XComTwitchAbilities.ini` - Contains config for various abilities created by Twitch Integration, which are used as part of actions.
* `XComTwitchChatCommands.ini` - Contains all of the commands your viewers can use to interact with the game.
* `XComTwitchPolls.ini` - Contains the specification for what poll types exist and what options are in them. Other options can be found in-game using MCM.
* `XComEncounters.ini` and `XComEncounterLists.ini` - Contain the definition of encounter groups that can be spawned by actions.

## Localization file

There's only one localization file, located at `Localization/TwitchIntegration.int`. You can add others for your preferred language if you like.

Within that file, there's some text you likely won't touch at the top, such as strings for the static parts of the UI. The useful parts for you will be adding text for any new poll events you define (sections starting with `PollChoice_` or `TwitchPollGroup_`). Make sure every poll group and choice have an entry in this file, or they won't work in-game.

Note that outcomes of the "roll the dice" chat command don't use the localization file. Their strings are hardcoded in `XComTwitchChatCommands.ini`.

## A word about balance

Balancing a complex game like XCOM 2 is a massive endeavor under the cleanest circumstances. When adding Twitch integration, so that hundreds of people have input on whether good or bad things happen to you, true balance is a fantasy. I recommend optimizing your configuration for the most fun experience for yourself and your viewers, and worrying about game balance afterwards.

Would your community enjoy watching you struggle against a Sectopod on turn 2 that spawned in the middle of your squad? You can do that! Do your viewers prefer a more laid-back experience where they vote on helpful options to ease your way through the mission? You can turn off the negative poll events completely if you like.

# Dev console

This mod adds a number of console commands, all of which start with the word "Twitch" so you can easily find them. Here are a few of the more key commands:

* `TwitchListRaffledViewers` - If you're raffling units, this can help you quickly see which viewers have won the raffle. Note that to see the output you need to use the full dev console (accessed with tilde, not backslash). This actually outputs all owned units and not just raffled ones.
* `TwitchRaffleUnitUnderMouse` - This re-raffles the unit closest to your mouse cursor (but will not raffle XCOM soldiers). You can use this if someone with an offensive username has won the raffle.
* `TwitchReassignUnitUnderMouse <name>` - Similar to the previous command, but you get to choose which viewer owns the unit. Remember that any viewer can only own one object at a time.
* `TwitchStartPoll <PollGroup>` - Starts a viewer poll. You can specify the poll group (see `XComTwitchPolls.ini` for options) but the actual options will be chosen randomly, per the normal poll logic.
* `TwitchEndPoll` - Ends the current poll immediately without waiting for its timer. The currently winning option will take effect.
* `TwitchRigRaffle <name>` - Rigs the next unit raffle so that the provided user wins, if eligible. If used multiple times, subsequent raffles will be rigged in order. Rigged raffles will not persist if a save game is loaded or if a tactical/strategy transition occurs.
* `TwitchClearRiggedRaffles` - Clears out the list of rigged raffles from the previous command.

And some less key commands:

* `TwitchUnassignViewer <name>` - Removes any unit ownership for the given viewer. May be needed if something breaks in the mod.
* `TwitchExecuteAction <ActionName>` - Executes the action with the given name. Mainly used for testing.