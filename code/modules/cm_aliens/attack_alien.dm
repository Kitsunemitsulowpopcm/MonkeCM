//This file deals with xenos clicking on stuff in general. Including mobs, objects, general atoms, etc.
//Abby

/*
 * Important note about attack_alien : In our code, attack_ procs are received by src, not dealt by src
 * For example, attack_alien defined for humans means what will happen to THEM when attacked by an alien
 * In that case, the first argument is always the attacker. For attack_alien, it should always be Xenomorph sub-types
 */

//If we're restrained, do nothing
/mob/living/carbon/Xenomorph/RestrainedClickOn(var/atom/A)
	return

//Generic proc for clicking things. We will move the remainder to attack_alien, a proc of our making
/mob/living/carbon/Xenomorph/UnarmedAttack(var/atom/A)
	A.attack_alien(src)
	next_move = world.time + (10 + attack_delay) //Adds some lag to the 'attack'

//The parent proc, will default to attack_paw behaviour unless overriden
/atom/proc/attack_alien(mob/user as mob)
	return ..(attack_paw(user))

/mob/living/carbon/human/attack_alien(mob/living/carbon/Xenomorph/M)

	if(isXenoLarva(M)) //Larvas have no means to attack humans
		M.visible_message("<span class='danger'>[M] nudges its head against [src].</span>", \
		"<span class='danger'>You nudge your head against [src].</span>")
		return 0

	//Reviewing the four primary intents
	switch(M.a_intent)

		if("help")
			M.visible_message("<span class='notice'>\The [M] caresses [src] with its scythe-like arm.</span>", \
			"<span class='notice'>You caress [src] with your scythe-like arm.</span>")

		if("grab") //Defaults to ctrl-click pull. Grabs are fucked up!
			if(M == src || anchored)
				return 0

			if(check_shields(0, M.name) && prob(66)) //Bit of a bonus
				M.visible_message("<span class='danger'>\The [M]'s grab is blocked by [src]'s shield!</span>", \
				"<span class='danger'>Your grab was blocked by [src]'s shield!</span>")
				playsound(loc, 'sound/weapons/punchmiss.ogg', 50, 1, -1) //Feedback
				return 0

			if(Adjacent(M)) //Logic!
				M.start_pulling(src)
				M.update_icons() //To immediately show the grab

				M.visible_message("<span class='warning'>[M] grabs [src]!</span>", \
				"<span class='warning'>You grab [src]!</span>")
				playsound(loc, 'sound/weapons/thudswoosh.ogg', 50, 1, -1)

		if("hurt")
			if(!slashing_allowed && !M.is_intelligent)
				M << "<span class='warning'>Slashing is currently <b>forbidden</b> by the Queen. You refuse to slash [src].</span>"
				return 0

			if(stat == DEAD)
				M << "<span class='warning'>[src] is dead, why would you want to touch it?</span>"
				return 0

			if(slashing_allowed == 2 && !M.is_intelligent)
				if(src.status_flags & XENO_HOST)
					M << "<span class='warning'>You try to slash [src], but find you <B>cannot</B>. There is a host inside!</span>"
					return 0

				if(M.health > round(2 * M.maxHealth / 3)) //Note : Under 66 % health
					M << "<span class='warning'>You try to slash [src], but find you <B>cannot</B>. You are not yet injured enough to overcome the Queen's orders.</span>"
					return 0

			if(check_shields(0, M.name) && prob(66)) //Bit of a bonus
				M.visible_message("<span class='danger'>\The [M]'s slash is blocked by [src]'s shield!</span>", \
				"<span class='danger'>Your slash is blocked by [src]'s shield!</span>")
				return 0

			//From this point, we are certain a full attack will go out. Calculate damage and modifiers
			var/damage = rand(M.melee_damage_lower, M.melee_damage_upper)

			//Frenzy auras stack in a way, then the raw value is multipled by two to get the additive modifier
			if(M.frenzy_aura > 0)
				damage += (M.frenzy_aura * 2)

			//Check for a special bite attack
			if(M.check_bite(src))
				return 1

			//Check for a special tail attack
			if(M.check_tail_attack(src))
				return 1

			//Somehow we will deal no damage on this attack
			if(!damage)
				playsound(M.loc, 'sound/weapons/slashmiss.ogg', 50, 1, -1)
				M.visible_message("<span class='danger'>\The [M] lunges at [src]!</span>", \
				"<span class='danger'>You lunge at [src]!</span>")
				return 0

			var/datum/organ/external/affecting
			affecting = get_organ(ran_zone(M.zone_sel.selecting, 70))
			if(!affecting) //No organ, just get a random one
				affecting = get_organ(ran_zone(null, 0))
			if(!affecting) //Still nothing??
				affecting = get_organ("chest") //Gotta have a torso?!

			var/armor_block = run_armor_check(affecting, "melee")

			if(isYautja(src) && check_zone(M.zone_sel.selecting) == "head")
				if(istype(wear_mask, /obj/item/clothing/mask/gas/yautja))
					var/knock_chance = 1
					if(M.frenzy_aura)
						knock_chance += 2
					if(M.is_intelligent)
						knock_chance += 2
					knock_chance += min(round(damage * 0.25), 10) //Maximum of 15% chance.
					if(prob(knock_chance))
						playsound(loc, 'sound/effects/metalhit.ogg', 100, 1, 1)
						M.visible_message("<span class='danger'>The [M] smashes off [src]'s [wear_mask.name]!</span>", \
						"<span class='danger'>You smash off [src]'s [wear_mask.name]!</span>")
						drop_inv_item_on_ground(wear_mask)
						emote("roar")
						return 1

			//The normal attack proceeds
			playsound(loc, 'sound/weapons/slice.ogg', 25, 1, -1)
			M.visible_message("<span class='danger'>\The [M] slashes [src]!</span>", \
			"<span class='danger'>You slash [src]!</span>")
			forcesay()

			//Logging, including anti-rulebreak logging
			if(src.status_flags & XENO_HOST && src.stat != DEAD)
				if(istype(src.buckled, /obj/structure/stool/bed/nest)) //Host was buckled to nest while infected, this is a rule break
					src.attack_log += text("\[[time_stamp()]\] <font color='orange'><B>was slashed by [M.name] ([M.ckey]) while they were infected and nested</B></font>")
					M.attack_log += text("\[[time_stamp()]\] <font color='red'><B>slashed [src.name] ([src.ckey]) while they were infected and nested</B></font>")
					msg_admin_ff("[key_name(M)] slashed [key_name(src)] while they were infected and nested.") //This is a blatant rulebreak, so warn the admins
				else //Host might be rogue, needs further investigation
					src.attack_log += text("\[[time_stamp()]\] <font color='orange'>was slashed by [M.name] ([M.ckey]) while they were infected</font>")
					M.attack_log += text("\[[time_stamp()]\] <font color='red'>slashed [src.name] ([src.ckey]) while they were infected</font>")
			else //Normal xenomorph friendship with benefits
				src.attack_log += text("\[[time_stamp()]\] <font color='orange'>was slashed by [M.name] ([M.ckey])</font>")
				M.attack_log += text("\[[time_stamp()]\] <font color='red'>slashed [src.name] ([src.ckey])</font>")
			log_attack("[M.name] ([M.ckey]) slashed [src.name] ([src.ckey])")

			apply_damage(damage, BRUTE, affecting, armor_block, sharp = 1, edge = 1) //This should slicey dicey
			updatehealth()

		if("disarm")
			if(check_shields(0, M.name) && prob(66)) //Bit of a bonus
				M.visible_message("<span class='danger'>\The [M]'s tackle is blocked by [src]'s shield!</span>", \
				"<span class='danger'>Your tackle is blocked by [src]'s shield!</span>")
				return 0
			if(weakened)
				if(prob(20))
					playsound(loc, 'sound/weapons/pierce.ogg', 25, 1, -1)
					Weaken(rand(M.tacklemin, M.tacklemax)) //Min and max tackle strenght. They are located in individual caste files.
					M.visible_message("<span class='danger'>\The [M] tackles down [src]!</span>", \
					"<span class='danger'>You tackle down [src]!</span>")
				else
					playsound(loc, 'sound/weapons/punchmiss.ogg', 50, 1, -1)
					M.visible_message("<span class='danger'>\The [M] tries to tackle [src], but they are already down!</span>", \
					"<span class='danger'>You try to tackle [src], but they are already down!</span>")

			else
				var/tackle_bonus = 0
				if(M.frenzy_aura)
					tackle_bonus = (M.frenzy_aura * 3)
				if(prob(M.tackle_chance + tackle_bonus)) //Tackle_chance is now a special var for each caste.
					playsound(loc, 'sound/weapons/pierce.ogg', 25, 1, -1)
					Weaken(rand(M.tacklemin, M.tacklemax))
					M.visible_message("<span class='danger'>\The [M] tackles down [src]!</span>", \
					"<span class='danger'>You tackle down [src]!</span>")
				else
					playsound(loc, 'sound/weapons/punchmiss.ogg', 50, 1, -1)
					M.visible_message("<span class='danger'>\The [M] tries to tackle [src]</span>", \
					"<span class='danger'>You try to tackle [src]</span>")
	return 1

//Every other type of nonhuman mob
/mob/living/attack_alien(mob/living/carbon/Xenomorph/M)

	if(isXenoLarva(M)) //Larvas have no means to attack humans
		M.visible_message("<span class='danger'>[M] nudges its head against [src].</span>", \
		"<span class='danger'>You nudge your head against [src].</span>")
		return 0

	switch(M.a_intent)
		if("help")
			M.visible_message("<span class='notice'>\The [M] caresses [src] with its scythe-like arm.</span>", \
			"<span class='notice'>You caress [src] with your scythe-like arm.</span>")
			return 0

		if("grab")
			if(M == src || anchored)
				return 0

			if(Adjacent(M)) //Logic!
				M.start_pulling(src)
				M.update_icons() //To immediately show the grab

				M.visible_message("<span class='warning'>[M] grabs [src]!</span>", \
				"<span class='warning'>You grab [src]!</span>")
				playsound(loc, 'sound/weapons/thudswoosh.ogg', 50, 1, -1)

		if("hurt")
			if(isXeno(src)) //Can't slash other xenos for now
				M.visible_message("<span class='warning'>\The [M] nibbles [src].</span>", \
				"<span class='warning'>You nibble [src].</span>")
				return 1
			if(issilicon(src) && stat != DEAD) //A bit of visual flavor for attacking Cyborgs/pAIs. Sparks!
				var/datum/effect/effect/system/spark_spread/spark_system
				spark_system = new /datum/effect/effect/system/spark_spread()
				spark_system.set_up(5, 0, src)
				spark_system.attach(src)
				spark_system.start()
			var/damage = (rand(M.melee_damage_lower, M.melee_damage_upper) + 3)
			M.visible_message("<span class='danger'>\The [M] bites [src]!</span>", \
			"<span class='danger'>You bite [src]!</span>")
			apply_damage(damage, BRUTE)

		if("disarm")
			playsound(loc, 'sound/weapons/thudswoosh.ogg', 50, 1, -1)
			M.visible_message("<span class='warning'>\The [M] shoves [src]!</span>", \
			"<span class='warning'>You shove [src]!</span>")
			if(ismonkey(src))
				Weaken(8)
	return 0

//This proc is here to prevent Xenomorphs from picking up objects (default attack_hand behaviour)
//Note that this is overriden by every proc concerning a child of obj unless inherited
/obj/attack_alien(mob/living/carbon/Xenomorph/M)

	if(isXenoLarva(M)) //Larvae don't do anything
		return 0

	if(istype(src,/obj/item/clothing/mask/facehugger)) //Xenomorphs can pick up huggers for the time being
		attack_hand(M)
		return

	if(istype(src, /obj/item)) //Can't pick up anything else
		return 0

	..() //Default to generic atom proc for everything else that may be
	return 1

//Closets are used just like humans would
/obj/structure/closet/attack_alien(mob/user as mob)
	if(isXenoLarva(user)) //Larvae can't do shit
		return 0
	return src.attack_hand(user)

//Breaking tables and racks
/obj/structure/table/attack_alien(mob/living/carbon/Xenomorph/M)
	if(isXenoLarva(M)) //Larvae can't do shit
		return 0
	if(breakable)
		playsound(src, 'sound/effects/metalhit.ogg', 100, 1)
		health -= rand(M.melee_damage_lower, M.melee_damage_upper)
		if(health <= 0)
			M.visible_message("<span class='danger'>\The [M] slices [src] apart!</span>", \
			"<span class='danger'>You slice [src] apart!</span>")
			destroy()
		else
			M.visible_message("<span class='danger'>[M] slashes [src]!</span>", \
			"<span class='danger'>You slash [src]!</span>")

//Breaking barricades
/obj/structure/m_barricade/attack_alien(mob/living/carbon/Xenomorph/M)
	if(isXenoLarva(M)) //Larvae can't do shit
		return 0
	health -= rand(M.melee_damage_lower, M.melee_damage_upper)
	playsound(src, 'sound/effects/metalhit.ogg', 100, 1)
	if(health <= 0)
		M.visible_message("<span class='danger'>\The [M] slices [src] apart!</span>", \
		"<span class='danger'>You slice [src] apart!</span>")
	else
		M.visible_message("<span class='danger'>[M] slashes [src]!</span>", \
		"<span class='danger'>You slash [src]!</span>")
	update_health()

/obj/structure/rack/attack_alien(mob/living/carbon/Xenomorph/M)
	if(isXenoLarva(M)) //Larvae can't do shit
		return 0
	playsound(src, 'sound/effects/metalhit.ogg', 100, 1)
	M.visible_message("<span class='danger'>\The [M] slices [src] apart!</span>", \
	"<span class='danger'>You slice [src] apart!</span>")
	destroy()

//Default "structure" proc. This should be overwritten by sub procs.
//If we sent it to monkey we'd get some weird shit happening.
/obj/structure/attack_alien(mob/living/carbon/Xenomorph/M)
	return 0

//Smashing lights
/obj/machinery/light/attack_alien(mob/living/carbon/Xenomorph/M)
	if(isXenoLarva(M)) //Larvae can't do shit
		return 0
	if(status == 2) //Ignore if broken. Note that we can't use defines here
		return 0

	M.visible_message("<span class='danger'>\The [M] smashes [src]!</span>", \
	"<span class='danger'>You smash [src]!</span>")
	broken() //Smashola!

//Smashing windows
/obj/structure/window/attack_alien(mob/living/carbon/Xenomorph/M)
	if(isXenoLarva(M)) //Larvae can't do shit
		return 0
	if(M.a_intent == "help")
		playsound(src.loc, 'sound/effects/glassknock.ogg', 80, 1)
		M.visible_message("<span class='warning'>\The [M] creepily taps on [src] with its huge claw.</span>", \
		"<span class='warning'>You creepily tap on [src].</span>", \
		"<span class='warning'>You hear a glass tapping sound.</span>")
	else
		attack_generic(M, M.melee_damage_lower)

//Slashing bots
/obj/machinery/bot/attack_alien(mob/living/carbon/Xenomorph/M)
	if(isXenoLarva(M)) //Larvae can't do shit
		return 0
	health -= rand(15, 30)
	if(health <= 0)
		M.visible_message("<span class='danger'>\The [M] slices [src] apart!</span>", \
		"<span class='danger'>You slice [src] apart!</span>")
	else
		M.visible_message("<span class='danger'>[M] slashes [src]!</span>", \
		"<span class='danger'>You slash [src]!</span>")
	playsound(src.loc, 'sound/weapons/slice.ogg', 25, 1, -1)
	if(prob(10))
		new /obj/effect/decal/cleanable/blood/oil(src.loc)
	healthcheck()

//Slashing cameras
/obj/machinery/camera/attack_alien(mob/living/carbon/Xenomorph/M)
	if(isXenoLarva(M)) //Larvae can't do shit
		return 0
	if(status)
		status = 0
		M.visible_message("<span class='danger'>\The [M] slices [src] apart!</span>", \
		"<span class='danger'>You slice [src] apart!</span>")
		playsound(src.loc, 'sound/weapons/slash.ogg', 100, 1)
		icon_state = "[initial(icon_state)]1"
		add_hiddenprint(M)
		deactivate(M, 0)

//Slashing windoors
/obj/machinery/door/window/attack_alien(mob/living/carbon/Xenomorph/M)
	if(isXenoLarva(M)) //Larvae can't do shit
		return 0
	playsound(src.loc, 'sound/effects/Glasshit.ogg', 75, 1)
	M.visible_message("<span class='danger'>[M] smashes against [src]!</span>", \
	"<span class='danger'>You smash against [src]!</span>")
	var/damage = 25
	if(M.big_xeno)
		damage = 40
	take_damage(damage)

//Slashing mechas
/obj/mecha/attack_alien(mob/living/carbon/Xenomorph/M)
	if(isXenoLarva(M)) //Larvae can't do shit
		return 0
	log_message("Attack by claw. Attacker - [M].", 1)

	if(!prob(deflect_chance))
		take_damage((rand(M.melee_damage_lower, M.melee_damage_upper)/2))
		check_for_internal_damage(list(MECHA_INT_TEMP_CONTROL, MECHA_INT_TANK_BREACH, MECHA_INT_CONTROL_LOST))
		playsound(src.loc, 'sound/weapons/slash.ogg', 50, 1, -1)
		M.visible_message("<span class='danger'>[M] slashes [src]'s armor!</span>", \
		"<span class='danger'>You slash [src]'s armor!</span>")
	else
		src.log_append_to_last("Armor saved.")
		playsound(src.loc, 'sound/weapons/slash.ogg', 50, 1, -1)
		M.visible_message("<span class='warning'>[M] slashes [src]'s armor to no effect!</span>", \
		"<span class='danger'>You slash [src]'s armor to no effect!</span>")

//Slashing grilles
/obj/structure/grille/attack_alien(mob/living/carbon/Xenomorph/M)
	if(isXenoLarva(M)) //Larvae can't do shit
		return 0
	playsound(loc, 'sound/effects/grillehit.ogg', 80, 1)
	var/damage_dealt = 5
	M.visible_message("<span class='danger'>\The [M] mangles [src]!</span>", \
	"<span class='danger'>You mangle [src]!</span>", \
	"<span class='danger'>You hear twisting metal!</span>")

	if(shock(M, 70))
		M.visible_message("<span class='danger'>ZAP! \The [M] spazzes wildly amongst a smell of burnt ozone.</span>", \
		"<span class='danger'>ZAP! You twitch and dance like a monkey on hyperzine!</span>", \
		"<span class='danger'>You hear a sharp ZAP and a smell of ozone.</span>")
		return 0 //Intended apparently ?

	health -= damage_dealt
	healthcheck()

//Slashin mirrors
/obj/structure/mirror/attack_alien(mob/living/carbon/Xenomorph/M)
	if(isXenoLarva(M)) //Larvae can't do shit
		return 0
	if(shattered)
		playsound(loc, 'sound/effects/hit_on_shattered_glass.ogg', 70, 1)
		return 1

	if(M.a_intent == "help")
		M.visible_message("<span class='warning'>\The [M] oogles its own reflection in [src].</span>", \
		"<span class='warning'>You oogle your own reflection in [src].</span>")
	else
		M.visible_message("<span class='danger'>\The [M] smashes [src]!</span>", \
		"<span class='danger'>You smash [src]!</span>")
		shatter()

//Foamed metal
/obj/structure/foamedmetal/attack_alien(mob/living/carbon/Xenomorph/M)
	if(isXenoLarva(M)) //Larvae can't do shit
		return 0
	if(prob(33))
		M.visible_message("<span class='danger'>\The [M] slices [src] apart!</span>", \
		"<span class='danger'>You slice [src] apart!</span>")
		cdel(src)
		return 1
	else
		M.visible_message("<span class='danger'>\The [M] tears some shreds off [src]!</span>", \
		"<span class='danger'>You tear some shreds off [src]!</span>")

//Wooden barricades
/obj/structure/barricade/wooden/attack_alien(mob/living/carbon/Xenomorph/M)
	if(isXenoLarva(M)) //Larvae can't do shit
		return 0
	health -= rand(M.melee_damage_lower, M.melee_damage_upper)
	playsound(src, 'sound/effects/woodhit.ogg', 100, 1)
	if(health <= 0)
		M.visible_message("<span class='danger'>\The [M] slices [src] apart!</span>", \
		"<span class='danger'>You slice [src] apart!</span>")
		destroy()
	else
		M.visible_message("<span class='danger'>[M] slashes [src]!</span>", \
		"<span class='danger'>You slash [src]!</span>")

//Prying open doors
/obj/machinery/door/airlock/attack_alien(mob/living/carbon/Xenomorph/M)
	var/turf/cur_loc = M.loc
	if(isElectrified())
		if(shock(M, 70))
			return
	if(locked)
		M << "<span class='warning'>\The [src] is bolted down tight.</span>"
		return 0
	if(welded)
		M << "<span class='warning'>\The [src] is welded shut.</span>"
		return 0
	if(!istype(cur_loc))
		return 0 //Some basic logic here
	if(!density)
		M << "<span class='warning'>\The [src] is already open!</span>"
		return 0

	if(isXenoLarva(M)) //Larvae cannot pry open doors, but they CAN squeeze under them.
		for(var/atom/movable/AM in get_turf(src))
			if(AM != src && AM.density && !AM.CanPass(M, M.loc))
				M << "<span class='warning'>\The [AM] prevents you from squeezing under \the [src]!</span>"
				return 0
		M.visible_message("<span class='warning'>\The [M] scuttles underneath \the [src]!</span>", \
		"<span class='warning'>You squeeze and scuttle underneath \the [src].</span>")
		if(!isnull(loc)) //Logic
			M.loc = loc
			return 0

	playsound(loc, 'sound/effects/metal_creaking.ogg', 50, 1)
	M.visible_message("<span class='warning'>\The [M] digs into \the [src] and begins to pry it open.</span>", \
	"<span class='warning'>You dig into \the [src] and begin to pry it open.</span>")

	if(do_after(M, 40, FALSE))
		if(M.loc != cur_loc)
			return 0 //Make sure we're still there
		if(locked)
			M << "<span class='warning'>\The [src] is bolted down tight.</span>"
			return 0
		if(welded)
			M << "<span class='warning'>\The [src] is welded shut.</span>"
			return 0
		if(density) //Make sure it's still closed
			spawn(0)
				open(1)
				M.visible_message("<span class='danger'>\The [M] pries \the [src] open.</span>", \
				"<span class='danger'>You pry \the [src] open.</span>")

//Prying open FIREdoors
/obj/machinery/door/firedoor/attack_alien(mob/living/carbon/Xenomorph/M)
	if(isXenoLarva(M)) //Larvae can't do shit
		return 0
	var/turf/cur_loc = M.loc
	if(blocked)
		M << "<span class='warning'>\The [src] is welded shut.</span>"
		return 0
	if(!istype(cur_loc))
		return 0 //Some basic logic here
	if(!density)
		M << "<span class='warning'>\The [src] is already open!</span>"
		return 0

	playsound(src.loc, 'sound/effects/metal_creaking.ogg', 50, 1)
	M.visible_message("<span class='warning'>\The [M] digs into \the [src] and begins to pry it open.</span>", \
	"<span class='warning'>You dig into \the [src] and begin to pry it open.</span>")

	if(do_after(M, 30, FALSE))
		if(M.loc != cur_loc)
			return 0 //Make sure we're still there
		if(blocked)
			M << "<span class='warning'>\The [src] is welded shut.</span>"
			return 0
		if(density) //Make sure it's still closed
			spawn(0)
				open(1)
				M.visible_message("<span class='danger'>\The [M] pries \the [src] open.</span>", \
				"<span class='danger'>You pry \the [src] open.</span>")

//Beds, nests and chairs - unbuckling
/obj/structure/stool/bed/attack_alien(mob/living/carbon/Xenomorph/M)
	if(isXenoLarva(M)) //Larvae can't do shit
		return 0
	attack_hand(M)

//Nerfing the damn Cargo Tug Train
/obj/vehicle/train/attack_alien(mob/living/carbon/Xenomorph/M)
	if(isXenoLarva(M)) //Larvae can't do shit
		return 0
	attack_hand(M)

//clicking on resin doors attacks them, or opens them without harm intent
/obj/structure/mineral_door/resin/attack_alien(mob/living/carbon/Xenomorph/M)
	var/turf/cur_loc = M.loc
	if(!istype(cur_loc))
		return 0 //Some basic logic here
	if(M.a_intent != "hurt")
		TryToSwitchState(M)
		return 1

	if(isXenoLarva(M)) //Larvae don't rip door resin doors
		return 0
	M.visible_message("<span class='warning'>\The [M] digs into \the [src] and begins ripping it down.</span>", \
	"<span class='warning'>You dig into \the [src] and begin ripping it down.</span>")
	if(do_after(M, 80, FALSE))
		if(!src)
			return 0 //Someone already destroyed it, do_after should check this but best to be safe
		if(M.loc != cur_loc)
			return 0 //Make sure we're still there
		M.visible_message("<span class='danger'>[M] rips down \the [src]!</span>", \
		 "<span class='danger'>You rip down \the [src]!</span>")
		cdel(src)

//Xenomorphs can't use machinery, not even the "intelligent" ones
//Exception is Queen and shuttle computers, because plot power
/obj/machinery/attack_alien(mob/living/carbon/Xenomorph/M)
	if(isXenoLarva(M)) //Larvae can't do shit
		return 0
	M << "<span class='warning'>You stare at \the [src] cluelessly.</span>"

/obj/machinery/computer/shuttle_control/attack_alien(mob/living/carbon/Xenomorph/M)
	var/datum/shuttle/ferry/shuttle = shuttle_controller.shuttles[shuttle_tag]
	if(M.is_intelligent)
		attack_hand(M)
		if(!shuttle.queen_locked && !shuttle.iselevator && onboard) //This is the shuttle's onboard console and we have not hijacked it yet
			M << "<span class='xenonotice'>You interact with the pilot's console and disable remote control.</span>"
			shuttle.queen_locked = 1
	else
		..()

//APCs.
/obj/machinery/power/apc/attack_alien(mob/living/carbon/Xenomorph/M)
	if(isXenoLarva(M)) //Larvae can't do shit
		return 0
	M.visible_message("<span class='danger'>[M] slashes \the [src]!</span>", \
	"<span class='danger'>You slash \the [src]!</span>")
	playsound(src.loc, 'sound/weapons/slash.ogg', 100, 1)
	var/allcut = 1
	for(var/wire in apcwirelist)
		if(!isWireCut(apcwirelist[wire]))
			allcut = 0
			break

	if(beenhit >= pick(3, 4) && wiresexposed != 1)
		wiresexposed = 1
		update_icon()
		visible_message("<span class='danger'>\The [src]'s cover swings open, exposing the wires!</span>")

	else if(wiresexposed == 1 && allcut == 0)
		for(var/wire in apcwirelist)
			cut(apcwirelist[wire])
		update_icon()
		visible_message("<span class='danger'>\The [src]'s wires snap apart in a rain of sparks!")
	else
		beenhit += 1

//Snow barricades
/obj/structure/barricade/snow/attack_alien(mob/living/carbon/Xenomorph/M)
	if(isXenoLarva(M)) //Larvae can't do shit
		return 0
	health -= rand(M.melee_damage_lower, M.melee_damage_upper)
	if(health <= 0)
		M.visible_message("<span class='danger'>\The [M] slices \the [src] apart!</span>", \
		"<span class='danger'>You slice \the [src] apart!</span>")
	else
		M.visible_message("<span class='danger'>[M] slashes \the [src]!</span>", \
		"<span class='danger'>You slash \the [src]!</span>")
	health_check()
	playsound(M.loc, 'sound/weapons/slashmiss.ogg', 50, 1, -1)

/obj/structure/ladder/attack_alien(mob/living/carbon/Xenomorph/M)
	return attack_hand(M)

/obj/machinery/colony_floodlight/attack_alien(mob/living/carbon/Xenomorph/M)
	return attack_hand(M)

//Digging up snow
/turf/unsimulated/floor/snow/attack_alien(mob/living/carbon/Xenomorph/M)
	if(isXenoLarva(M)) //Larvae can't do shit
		return 0
	if(M.a_intent == "grab")

		if(!slayer)
			M << "<span class='warning'>There is nothing to clear out!</span>"
			return 0

		M.visible_message("<span class='notice'>\The [M] starts clearing out \the [src].</span>", \
		"<span class='notice'>You start clearing out \the [src].</span>")
		playsound(M.loc, 'sound/weapons/slashmiss.ogg', 50, 1, -1)
		if(!do_after(M, 25, FALSE))
			return 0

		if(!slayer)
			M  << "<span class='warning'>There is nothing to clear out!</span>"
			return

		M.visible_message("<span class='notice'>\The [M] clears out \the [src].</span>", \
		"<span class='notice'>You clear out \the [src].</span>")
		slayer -= 1
		update_icon(1, 0)

//Crates, closets, other paraphernalia
/obj/structure/largecrate/attack_alien(mob/living/carbon/Xenomorph/M)
	if(isXenoLarva(M)) //Larvae can't do shit
		return 0
	playsound(src, 'sound/effects/woodhit.ogg', 100, 1)
	new /obj/item/stack/sheet/wood(src)
	var/turf/T = get_turf(src)
	for(var/obj/O in contents)
		O.loc = T
	M.visible_message("<span class='danger'>\The [M] smashes \the [src] apart!</span>", \
	"<span class='danger'>You smash \the [src] apart!</span>", \
	"<span class='danger'>You hear splitting wood:!/span>")
	cdel(src)

/obj/structure/closet/attack_alien(mob/living/carbon/Xenomorph/M)
	if(isXenoLarva(M)) //Larvae can't do shit
		return 0
	if(M.a_intent == "hurt" && !unacidable)
		if(prob(70))
			var/turf/T = get_turf(src)
			for(var/obj/O in contents)
				O.loc = T
			M.visible_message("<span class='danger'>\The [M] smashes \the [src] open!</span>", \
			"<span class='danger'>You smash \the [src] open!</span>")
		else
			M.visible_message("<span class='danger'>\The [M] smashes \the [src]!</span>", \
			"<span class='danger'>You smash \the [src]!</span>")
	else
		return attack_paw(M)

/obj/structure/girder/attack_alien(mob/living/carbon/Xenomorph/M)
	if(isXenoLarva(M)) //Larvae can't do shit
		return 0
	if(M.melee_damage_lower < 28 || unacidable)
		M << "<span class='warning'>Your claws aren't sharp enough to damage \the [src].</span>"
		return 0
	else
		health -= round(rand(M.melee_damage_lower, M.melee_damage_upper) / 2)
		if(health <= 0)
			M.visible_message("<span class='danger'>\The [M] smashes \the [src] apart!</span>", \
			"<span class='danger'>You slice \the [src] apart!</span>")
			playsound(loc, 'sound/effects/metalhit.ogg', 75, 1)
			dismantle()
		else
			M.visible_message("<span class='danger'>[M] smashes \the [src]!</span>", \
			"<span class='danger'>You slash \the [src]!</span>")
			playsound(loc, 'sound/effects/metalhit.ogg', 25, 1)

/obj/machinery/vending/attack_alien(mob/living/carbon/Xenomorph/M)
	if(isXenoLarva(M)) //Larvae can't do shit
		return 0
	if(tipped_level)
		M << "<span class='warning'>There's no reason to bother with that old piece of trash.</span>"
		return 0

	if(M.a_intent == "hurt")
		if(prob(M.melee_damage_lower))
			playsound(loc, 'sound/effects/metalhit.ogg', 75, 1)
			M.visible_message("<span class='danger'>\The [M] smashes \the [src] beyond recognition!</span>", \
			"<span class='danger'>You enter a frenzy and smash \the [src] apart!</span>")
			malfunction()
			return 1
		else
			M.visible_message("<span class='danger'>[M] slashes \the [src]!</span>", \
			"<span class='danger'>You slash \the [src]!</span>")
			playsound(loc, 'sound/effects/metalhit.ogg', 25, 1)
		return 1

	M.visible_message("<span class='warning'>\The [M] begins to lean against \the [src].</span>", \
	"<span class='warning'>You begin to lean against \the [src].</span>")
	tipped_level = 1
	var/shove_time = 100
	if(M.big_xeno)
		shove_time = 50
	if(istype(M,/mob/living/carbon/Xenomorph/Crusher))
		shove_time = 15
	if(do_after(M, shove_time, FALSE))
		M.visible_message("<span class='danger'>\The [M] knocks \the [src] down!</span>", \
		"<span class='danger'>You knock \the [src] down!</span>")
		tip_over()
	else
		tipped_level = 0

/obj/structure/inflatable/attack_alien(mob/living/carbon/Xenomorph/M)
	if(isXenoLarva(M)) //Larvas have no means to attack inflatable barriers
		M.visible_message("<span class='danger'>[M] nudges its head against \the [src].</span>", \
		"<span class='danger'>You nudge your head against \the [src].</span>")
		return 0
	deflate(1)

/obj/machinery/vending/proc/tip_over()
	var/matrix/A = matrix()
	tipped_level = 2
	density = 0
	A.Turn(90)
	transform = A
	malfunction()

/obj/machinery/vending/proc/flip_back()
	icon_state = initial(icon_state)
	tipped_level = 0
	density = 1
	stat &= ~BROKEN //Remove broken. MAGICAL REPAIRS
