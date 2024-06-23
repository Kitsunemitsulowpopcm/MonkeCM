/datum/job/command/bridge
	title = JOB_SO
	total_positions = 3
	spawn_positions = 3
	flags_startup_parameters = ROLE_ADD_TO_DEFAULT
	gear_preset = /datum/equipment_preset/uscm_ship/so
	entry_message_body = "<a href='"+WIKI_PLACEHOLDER+"'>Your job is to command a platoon from the ground</a> You are in charge of executing the commanding officer's orders."

/datum/job/command/bridge/generate_entry_conditions(mob/living/M, whitelist_status)
	. = ..()
	if(!islist(GLOB.marine_leaders[JOB_SO]))
		GLOB.marine_leaders[JOB_SO] = list()
	GLOB.marine_leaders[JOB_SO] += M
	RegisterSignal(M, COMSIG_PARENT_QDELETING, PROC_REF(cleanup_leader_candidate))

/datum/job/command/bridge/proc/cleanup_leader_candidate(mob/M)
	SIGNAL_HANDLER
	GLOB.marine_leaders[JOB_SO] -= M

AddTimelock(/datum/job/command/bridge, list(
	JOB_SQUAD_LEADER = 1 HOURS,
	JOB_HUMAN_ROLES = 15 HOURS
))

/obj/effect/landmark/start/bridge
	name = JOB_SO
	icon_state = "so_spawn"
	job = /datum/job/command/bridge
