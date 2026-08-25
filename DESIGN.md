SeedyDotDot

SeedyDotDot is a tiny text-adventure game/engine written in Elixir.

It will live inside the Tidex repo, probably under:

examples/seedy_dot_dot/

Its primary purpose is to be a small but real application for developing, testing, dogfooding, and demonstrating Tidex. It may appear in the ExMex Termex/Tidex talk, but it should not consume much talk time: SeedyDotDot is the specimen Tidex operates on, not a major subject of the talk.

It should nevertheless be an actual playable game—small, funny, and interesting enough that programmers might run it themselves.

The name is a spoken rendering of:

cd ..

The project should retain the “Segvault” gag somewhere, as well as an NPC who at some point carries a Bitbucket.

General philosophy

Keep the project small.

Build it incrementally:

a little engine code
a little world data
a little engine code
a little world data
...

Every engine feature should be motivated by something we actually want to put into the game.

Avoid building a general adventure-game framework in anticipation of possible future requirements.

However, don’t unnecessarily paint the engine into a corner. Hal may eventually expand this into a more serious adventure-game engine.

The sample game should perhaps be around 5% as elaborate as Colossal Cave in content/richness: enough exploration, objects, state and puzzles to feel like a game, but still tiny.

Scope creep is the principal danger.

Engine vs. world

The engine should be theme-independent.

All atmosphere and game-specific material belongs in data.

The same engine should plausibly support:

* fantasy
* science fiction
* Star Trek-ish settings
* programming humor
* essentially unrelated text-adventure worlds

The engine understands concepts such as:

* rooms/locations
* exits
* objects
* inventory
* facts/state
* conditions
* actions/effects
* events
* challenges
* NPCs

It should NOT understand things such as Ruby, Elixir, dragons, computers, gems, spells, etc.

World definitions are immutable.

Game state represents current mutable reality.

Conceptually:

World
  starting definitions
Game
  current room
  current object locations
  mutable facts
  NPC locations/state
  pending challenge/timer state as needed

Avoid copying entire world definitions into mutable game state.

Development order

Start extremely small.

Each stage should remain playable.

Probable progression:

Stage 0  rooms + movement + CLI
Stage 1  objects + inventory
Stage 2  state + conditions
Stage 3  actions/effects
Stage 4  dynamic text
Stage 5  events
Stage 6  timed interaction
Stage 7  persistent NPCs
Stage 8  challenges + win/death
Stage 9  minimal web UI

This is NOT a binding roadmap.

Once the game itself starts creating new requirements, let:

GAME -> ENGINE

drive development rather than blindly following numbered stages.

CLI first

The initial UI should be textual.

The CLI is important because it gives us an extremely cheap way to exercise nearly the entire application without HTTP/browser machinery.

Conceptually:

> look
You are in a neglected computer science department...
> north
You enter a poorly illuminated corridor.

The game engine must not depend on the CLI.

Likewise, the later web UI must use the same underlying game API.

Something approximately like:

{new_game, output} = Game.command(game, "north")

Keep this interface simple.

Web UI

A web interface IS a required deliverable because SeedyDotDot may be used in a Tidex demo.

But it does not need to arrive early.

The CLI and transcript tests can develop and test most of the game before HTTP is introduced.

Eventually provide a tiny web application:

* no Phoenix
* probably Plug + Bandit
* no JS framework
* terminal-ish presentation
* transcript
* command input
* per-session game state

Tidex needs to manage only ONE long-running server for this project.

Do not create an architecture requiring asset servers, workers, databases, etc.

Initial DSL

Begin with the smallest DSL that can describe Stage 0.

Possible starting form:

start lobby
room lobby
  You are in the neglected lobby of what appears to have
  once been a respectable computer science department.
  A faded sign reads:
  ABANDON ALL FRAMEWORKS, YE WHO ENTER HERE.
  A corridor leads north.
  north corridor
end
room corridor
  You are in a poorly illuminated corridor.
  south lobby
  east ruby_room
end
room ruby_room
  Everything here is slightly too elegant.
  west corridor
end

Don’t over-design how prose and directives are distinguished yet.

Change the DSL when reality requires it.

Includes

We probably want a simple include directive fairly early.

Example:

include rooms.txt
include objects.txt

or:

include rooms/ruby_room.txt

Treat include as simple textual composition before parsing.

Included data should behave exactly as though it appeared inline.

Detect include cycles.

This allows a tiny world to remain in one file while permitting a larger future world to be organized naturally.

Objects

Stage 1 introduces physical objects.

An object minimally has:

* ID
* display name
* description
* starting location
* portable/non-portable

Commands:

take
get
drop
inventory
i
examine
look at
x

Keep noun matching simple initially.

Objects should be listed from current state rather than permanently embedded in room prose, since they can move.

The Ruby Room should contain an actual ruby once objects exist.

Also include at least one conspicuously non-portable object.

State and facts

Use a small fact vocabulary.

Dot notation has semantic meaning:

door.open
lamp.on
lamp.red
machine.active
oracle.annoyed
carrying.lamp

Prefer this over names such as:

door_is_open
carrying_lamp

Some facts are STORED:

door.open
machine.active

Some are DERIVED:

carrying.lamp
here.oracle

Derived facts should be calculated from existing game state rather than redundantly stored.

Provide one conceptual query mechanism:

Game.true?(game, "door.open")
Game.true?(game, "carrying.lamp")

Users of the condition system should not need to care whether a fact is stored or derived.

Initially facts are Boolean.

Do not add arbitrary values/comparisons until actual game content demands them.

Dynamic text

All atmospheric text lives in world data.

The text system should eventually support random alternatives.

Example:

You see {an ancient, well-scarred|a heavy soot-covered|an enormous oaken} door.

Empty alternatives are VALID:

The machine {hums|clicks|} quietly.

Multiple independent alternatives may appear in one string.

NO NESTING.

Also support conditional text using facts:

{?door.open:The door stands open.|The door is firmly closed.}

Either branch may be empty:

{?machine.active:A green light is glowing.|}
{?carrying.lamp:|It is too dark to see clearly.}

Do not initially add:

* nesting
* AND/OR
* comparisons
* variables
* arithmetic
* embedded Elixir
* weighted alternatives

Randomness must be controllable/injectable for testing.

Conditions

The same fact vocabulary should eventually be usable everywhere:

{?door.open:...|...}
north vault if door.open
require carrying.ruby
event if machine.active

Avoid creating separate condition languages for descriptions, exits, actions and events.

Multiple condition lines can imply AND before we need Boolean expression syntax.

Actions and effects

Eventually allow data-defined actions.

Conceptually:

action use ruby on console
  require carrying.ruby
  say The ruby fits into a suspiciously ruby-shaped socket.
  set machine.active
  set vault.open
end

Keep the effect vocabulary small.

Likely primitives:

say
set
clear
move

Eventually perhaps:

win
die

No embedded Elixir or arbitrary callbacks.

Events

Events make the world active.

An event consists roughly of:

trigger
optional conditions
effects

Potential triggers:

on enter ROOM
on leave ROOM
on take OBJECT
on drop OBJECT
on action ACTION
on turn

Support:

once

for events that should occur only once.

Allow random events with simple probability.

Example atmospheric event:

A bearded sysadmin rushes through the room carrying three
keyboards.
"DNS!" he shouts.
He disappears through the eastern door.

This character does NOT need to become an NPC.

Transient people/creatures can simply exist as event prose.

This is desirable for cheap atmosphere and jokes.

NPCs

Only create a persistent NPC when identity and persistence matter.

An NPC may:

* occupy a location
* be examined
* be talked to
* move
* remember simple state
* possess objects
* react to facts

Do NOT make every NPC an Elixir process just because this is Elixir.

Initially an NPC is simply world definition + mutable game state.

Use ordinary facts where possible:

oracle.annoyed
sysadmin.helpful

Object locations may eventually include:

{:room, :corridor}
:inventory
{:npc, :sysadmin}

At least one NPC somewhere in SeedyDotDot must carry a Bitbucket.

This can be completely ridiculous.

Timed interactions

One or two timed encounters are desirable.

Example:

A process appears.
"QUICK: VIM OR EMACS?"
You have five seconds.

A response before the deadline produces one result.

Failure to answer in time can itself produce text/effects.

Do not make normal gameplay time-sensitive.

Time must be injectable/fakeable in tests.

Tests must NEVER sleep waiting for real time.

Initially it is acceptable for timeout to be noticed on the player’s next action.

Active asynchronous timeout behavior can come later if needed.

Passwords/challenges

Some puzzles may ask for textual responses/passwords.

Answers may optionally be stored as cryptographic hashes rather than plaintext.

Purpose:

prevent casual grep-based spoilers

NOT:

serious security

Normalize answers predictably, probably trimming whitespace and optionally ignoring case.

Multiple acceptable answers should be possible if inexpensive.

Win/death

Eventually Game should have explicit status:

:playing
:won
:dead

Death should be rare and preferably funny.

Winning should be explicit and satisfying.

After win/death, ordinary commands should not continue mutating the game.

Support restart/new game.

Save/restore can wait until demonstrated necessary.

Testing philosophy

Testing is a major reason this project is useful for Tidex.

There are several distinct layers.

DSL/parser tests

Use tiny snippets of world data.

Test parsing independently of the canonical game.

World validation tests

Parsing answers:

Is this syntactically valid?

Validation answers:

Does this describe a coherent world?

Validate things such as:

* start room exists
* exit destinations exist
* IDs are unique
* object starting locations exist
* referenced NPCs/objects/events exist
* conditions/effects contain valid references
* include cycles do not exist

Distinguish errors from warnings where useful.

For example, a one-way exit may be intentional.

Engine tests

Engine tests should normally use tiny synthetic worlds constructed for the behavior being tested.

Examples:

* movement changes rooms
* blocked movement does not
* taking an object moves it to inventory
* setting a fact changes conditional behavior
* events fire correctly

The engine should NOT be intrinsically tied to the canonical SeedyDotDot world.

Transcript/integration tests

These DO run against the canonical shipped game.

They should be executable specifications/walkthroughs.

Desired syntax:

north
## /can't go that way/
look
## /in the machine room/
take widget
## /no widget here/

Ordinary line:

command sent to game

Assertion:

## /regexp/

means the output from the immediately preceding command must match the regexp.

Comments should also be supported separately:

# This verifies the eastern route.

Eventually support negative assertions:

## !/regexp/

Potential future test directives:

@advance 6

for simulated passage of time.

Do not make transcript tests nondeterministically fail because of random prose/events.

Eventually have at least one complete transcript that starts a new game and reaches victory.

That transcript becomes simultaneously:

* integration test
* regression test
* executable walkthrough
* proof that the shipped game remains solvable

Initial canonical world

Stage 0 begins with only three rooms.

LOBBY

You are in the neglected lobby of what appears to have once
been a respectable computer science department.
A faded sign reads:
ABANDON ALL FRAMEWORKS, YE WHO ENTER HERE.
A corridor leads north.

CORRIDOR

You are in a poorly illuminated corridor. The carpet has a
repeating pattern that may or may not terminate.
The lobby is south. A red door is east.

RUBY ROOM

Everything here is slightly too elegant. A small red gemstone
rests on a pedestal.
For reasons that are not yet implemented, you cannot take it.
The corridor is west.

Initial commands:

look
north / n
south / s
east / e
west / w

Invalid movement:

You can't go that way.

Unknown command:

I don't understand that.

CLI should also have a sane way to quit.

Stage 0 implementation shape

Probable files:

examples/seedy_dot_dot/
  mix.exs
  lib/
    seedy_dot_dot.ex
    seedy_dot_dot/
      world.ex
      game.ex
      cli.ex
  priv/
    dungeon.txt
  test/
    test_helper.exs
    world_test.exs
    game_test.exs

Do not regard this layout as sacred.

World should conceptually expose:

World.parse(text)
World.load(filename)
World.validate(world)

Game should conceptually expose:

Game.new(world)
Game.command(game, command)

CLI is a thin adapter over Game.

Tone of the sample game

Programming/computer-science humor, including:

* Elixir
* Ruby
* Unix/Linux
* AI
* “real” computer science
* programming-language/history jokes
* old adventure-game tropes

Prefer jokes that sometimes affect mechanics rather than merely funny room names.

Possible material:

* Ruby Mine / Ruby Room
* recursion room that returns to itself
* daemon wandering around
* zombie process that refuses to die
* supervisor that explains why killing a process didn’t help
* garbage collector removing something
* fork producing two passages
* race condition
* strongly typed door rejecting the wrong object
* AI Oracle confidently producing inconsistent answers
* Hall of Forgotten Languages
* Lambda Crypt
* Process Graveyard
* Hall of Deprecated Dependencies
* Infinite Recursion Room

And definitely preserve:

THE SEGVAULT

The exact gag is not fixed, but “Segvault” belongs somewhere in the finished tiny dungeon.

Likewise, somewhere an NPC must be carrying:

a Bitbucket

Do not explain these jokes to death.

Final development rule

Build:

smallest useful engine feature
-> immediately use it in game data
-> test it
-> play it
-> discover next pressure
-> repeat

SeedyDotDot should become interesting because a small number of general
mechanisms interact, not because the engine accumulates hundreds of features.

And remember why it exists:

It is primarily a compact, comprehensible, amusing REAL Elixir application
for exercising and demonstrating Tidex.

If SeedyDotDot starts delaying Tidex, cut scope.