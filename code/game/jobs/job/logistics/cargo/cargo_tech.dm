/datum/job/logistics/cargo
	title = JOB_CARGO_TECH
	total_positions = 2
	spawn_positions = 2
	supervisors = "the requisitions officer"
	selection_class = "job_ct"
	flags_startup_parameters = ROLE_ADD_TO_DEFAULT
	gear_preset = /datum/equipment_preset/uscm_ship/cargo
	entry_message_body = "<a href='"+WIKI_PLACEHOLDER+"'>Your job</a> is to dispense supplies to the marines, including weapon attachments. Stay in your department when possible to ensure the marines have full access to the supplies they may require. Listen to the radio in case someone requests a supply drop via the overwatch system."

/obj/effect/landmark/start/cargo
	name = JOB_CARGO_TECH
	icon_state = "ct_spawn"
	job = /datum/job/logistics/cargo
