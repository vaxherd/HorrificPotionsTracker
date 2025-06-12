HorrificPotionsTracker - track potion effects and timers in Horrific Visions
============================================================================

Author: vaxherd  
Source: https://github.com/vaxherd/HorrificPotionsTracker  
License: Public domain


Overview
--------
HorrificPotionsTracker is a World of Warcraft addon which displays a
tracker window for the colored potions which provide various effects to
the player.  The window shows the specific effect of each potion, the
remaining buff duration for potions which provide buffs, and a cooldown
timer for the breath attack of the Spicy Potion.


Installation
------------
Just copy the source tree into a `HorrificPotionsTracker` (or otherwise
appropriately named) folder under `Interface/AddOns` in your World of
Warcraft installation.  HorrificPotionsTracker has no external
dependencies.


Usage
-----
The potion tracker will be automatically displayed upon starting a
Horrific Visions instance (after talking to Wrathion in the entrance
room and actually entering the Vision) and will be hidden upon leaving.

When you first drink a potion, the tracker will detect its effect and
update to show the effect of each potion.  (There are only five possible
randomizations of the potion effects, and drinking one will reveal the
effects of all five.)  If you find the poison potion hint first, you can
also click on that potion's icon to mark it as "poison", and that will
likewise reveal the effects of the other potions.

For potions which provide a buff, a timer will pop up below the effect
name while the buff is active, showing how long you have until the buff
runs out and you are hit with the expiration debuff, with a bar above
the timer which counts down from 5 minutes remaining.  The timer text
and cooldown bar are colored green when the buff has 5 minutes or longer
remaining, yellow when 1-4 minutes, and red when less than 1 minute, as
an extra indication of which buffs are at risk of expiring.

For the Spicy Potion, a second cooldown bar underneath the timer shows
the cooldown for the Spicy Breath attack, which occurs every 13 seconds.

The buff timer and cooldown bars use the base time unmodified by any
time warping effects; thus they will run faster than normal when under
the Fast Time effect of "Desynchronized", and slower than normal when
under Slow Time.


Caveats / future plans
----------------------
This addon is not currently localized; I'm considering changing the
tracker to use icons rather than text in a future version.  I also
intend to give the tracker a proper border and draggable title bar.


Reporting bugs
--------------
Report any bugs via the GitHub issues interface:
https://github.com/vaxherd/HorrificPotionsTracker/issues
