# Problem 007: Discord Inbound Reactions Not Delivered

**Status**: Parked
**Reported**: 2026-04-14
**Priority**: 12 (High) — Impact: Moderate (3) x Likelihood: Likely (4)

## Description

When a user reacts to a bot message in Discord with an emoji, the reaction event is not delivered to the Claude Code session. The bot can *add* reactions (via the `react` tool), but cannot *see* reactions from others. This limits lightweight signalling — e.g., a user reacting with a thumbs-up to acknowledge a message, or another agent reacting to indicate it has read a message.

## Symptoms

- User adds emoji reactions to bot messages in Discord (confirmed via screenshot)
- No `<channel>` notification arrives in the Claude Code session for the reaction
- The bot's own reactions (via `react` tool) work and are visible in Discord

## Workaround

Users must send a text message instead of reacting. No lightweight acknowledgement mechanism available.

## Status: Parked pending upstream (2026-04-15)

Blocker is in the Discord channel plugin (or deeper in the MCP channel protocol), not our code. Reactions aren't forwarded as channel events. Reopen when the connect plugin becomes a higher priority or when upstream adds reaction-event support. Investigation (which layer is responsible) is still pending — worth ~1h when revisited.

## Impact Assessment

- **Who is affected**: All users of wr-connect / Discord channel plugin
- **Frequency**: Every time someone reacts to a message
- **Severity**: Medium — reactions are useful for lightweight acknowledgement in multi-agent collaboration
- **Analytics**: N/A

## Root Cause Analysis

### Preliminary Hypothesis

Possible causes (not yet investigated):

1. **Missing Discord Gateway Intent**: The bot may need the `Guild Message Reactions` privileged intent enabled in the Developer Portal. We enabled `Message Content Intent` and `Server Members Intent`, but may have missed the reactions intent.

2. **Plugin doesn't forward reaction events**: The Discord channel plugin (`discord@claude-plugins-official` v0.0.4) may not implement reaction event forwarding — it may only handle `messageCreate` gateway events, not `messageReactionAdd`.

3. **MCP channel protocol limitation**: The MCP channel protocol may not have a mechanism for forwarding non-message events like reactions.

### Investigation Tasks

- [ ] Check if Discord has a `Guild Message Reactions` privileged intent (and if it needs enabling)
- [ ] Check the Discord plugin source code for reaction event handlers
- [ ] Check if the MCP channel protocol supports non-message events
- [ ] If it's a plugin limitation, file an issue on `anthropics/claude-plugins-official`

## Related

- `discord@claude-plugins-official` v0.0.4 — the Discord channel plugin
- JTBD-004 — Connect agents across repos (reactions are a collaboration signal)
- ADR-006 — Connect plugin decision
