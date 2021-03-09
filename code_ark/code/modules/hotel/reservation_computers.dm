// Objects' visuals and basics

/obj/machinery/computer/modular/preset/hotel
	default_software = list(
		/datum/computer_file/program/hotel_reservations,
		/datum/computer_file/program/wordprocessor
	)
	autorun_program = /datum/computer_file/program/hotel_reservations

/obj/machinery/hotel_terminal
	name = "hotel reservations systems terminal"
	desc = "It can be used either for self-serivce reservations when set to automatic mode or as an ID scanner and payment terminal when operating in connection with a console."
	icon = 'code_ark/icons/obj/machinery.dmi'
	icon_state = "hotel_terminal"
	density = 1

	var/auto_mode = 1		// 0 - manual, 1 - auto
	var/program_mode = 1	// 0 - error, 1 - room selection, 2 - reservation, 3 - ID scan, 4 - payment

	var/reservation_duration = 1

	var/datum/nano_module/hotel_reservations/master_program
	var/datum/hotel_room/selected_room

	var/timeout_timer_id

/*/obj/item/weapon/stock_parts/circuitboard/hotel_terminal
	name = T_BOARD("hotel reservations system serivce terminal")
	build_path = /obj/machinery/hotel_terminal*/

/obj/machinery/hotel_terminal/Initialize()
	. = ..()
	setup_hotel_rooms()
	update_icon()

/obj/machinery/hotel_terminal/Destroy()
	if(master_program)
		master_program.connected_terminal = null
	. = ..()

/obj/machinery/hotel_terminal/attackby(obj/item/weapon/W, mob/user)
	var/obj/item/weapon/card/id/I = W.GetIdCard()

	if(I || istype(W, /obj/item/weapon/spacecash/ewallet))

		if(I == W || W == null)
			visible_message("<span class='info'>\The [usr] swipes \the [I] through \the [src].</span>")
		else
			visible_message("<span class='info'>\The [usr] swipes \the [W] through \the [src].</span>")

		if(program_mode == 3)
			if(!I)
				to_chat(user, "<span class='warning'>ID error. Check your ID.</span>")
				return
			var/datum/hotel_room/room_to_add_to
			if(!auto_mode && master_program)
				if(master_program.selected_room && master_program.reservation_status == 0)
					room_to_add_to = master_program.selected_room
			if(auto_mode && selected_room)
				room_to_add_to = selected_room
			if(room_to_add_to && I.registered_name != "Unknown")
				if(room_to_add_to.add_guest(I.registered_name))
					to_chat(user, "<span class='info'>Guest successfully added.</span>")
					if(auto_mode)
						program_mode = 2
						flick_screen(screen_icon_state = "hotel_terminal_loading")
					else
						if(LAZYLEN(room_to_add_to.room_guests) == room_to_add_to.guest_count)
							program_mode = 1
							flick_screen(screen_icon_state = "hotel_terminal_loading")
			else
				to_chat(user, "<span class='warning'>Unable to add the guest to the room.</span>")


/obj/machinery/hotel_terminal/on_update_icon()
	overlays.Cut()
	if(stat & (NOPOWER|BROKEN))
		set_light(0)
	var/screen_icon_state
	switch(program_mode)
		if(0)
			screen_icon_state = "hotel_terminal_error"
		if(1)
			if(auto_mode)
				screen_icon_state = "hotel_terminal_room_list"
			else
				screen_icon_state = "hotel_terminal_blocked"
		if(2)
			screen_icon_state = "hotel_terminal_room_reserve"
		if(3)
			screen_icon_state = "hotel_terminal_id_scan"
		if(4)
			screen_icon_state = "hotel_terminal_payment"
	var/image/I = image(icon, screen_icon_state)
	I.plane = EFFECTS_ABOVE_LIGHTING_PLANE
	I.layer = ABOVE_LIGHTING_LAYER
	overlays += I
	set_light(0.2, 0.5, 1, 2, "#cba561")

/obj/machinery/hotel_terminal/proc/flick_screen(var/screen_icon_state = "hotel_terminal_screensaver")
	if(stat & (NOPOWER|BROKEN))
		return
	overlays.Cut()
	var/image/I = image(icon, screen_icon_state)
	I.plane = EFFECTS_ABOVE_LIGHTING_PLANE
	I.layer = ABOVE_LIGHTING_LAYER
	overlays += I
	spawn(10)
		update_icon()


/obj/machinery/hotel_terminal/interface_interact(var/mob/user)
	flick_screen("hotel_terminal_screensaver")
	ui_interact(user)
	return TRUE

/obj/machinery/hotel_terminal/CanUseTopic(user, state)
	if(stat & (NOPOWER|BROKEN))
		to_chat(user, "<span class='warning'>\The [src] is broken!</span>")
		return STATUS_CLOSE
	return ..()

/obj/machinery/hotel_terminal/ui_interact(mob/user, ui_key = "main", var/datum/nanoui/ui = null, var/force_open = 1)

	var/list/data = new

	var/list/hotel_selected_room

	var/single_room_available = 0
	var/double_room_single_bed_available = 0
	var/double_room_two_beds_available = 0
	var/special_room_available = 0

	for(var/datum/hotel_room/R in GLOB.hotel_rooms)

		if (R == selected_room)
			if (R.room_status == 0 || R.room_status == 4)
				give_error()
			else
				hotel_selected_room = list(
					"number" = R.room_number,
					"status" = R.room_status,
					"beds" = R.bed_count,
					"capacity" = R.guest_count,
					"price" = R.hourly_price,
					"guests" = R.room_guests2text(),
					"guests_as_list" = R.room_guests,
					"guest_count" = LAZYLEN(R.room_guests),
					"start" = time2text(R.room_reservation_start_time, "hh:mm"),
					"end" = R.room_end_time2text(),
					"room_logs" = R.room_log
					)

		if (R.guest_count == 1 && !R.special_room && R.room_status == 1 && !single_room_available)
			single_room_available = R.hourly_price

		if (R.guest_count == 2 && R.bed_count == 1 && !R.special_room && R.room_status == 1 && !double_room_single_bed_available)
			double_room_single_bed_available = R.hourly_price

		if (R.guest_count == 2 && R.bed_count == 2 && !R.special_room && R.room_status == 1 && !double_room_two_beds_available)
			double_room_two_beds_available = R.hourly_price

		if(R.special_room == 1 && R.room_status == 1)
			special_room_available = 1

	data["mode"] = program_mode
	data["auto"] = auto_mode
	data["single_room"] = single_room_available
	data["double_single_room"] = double_room_single_bed_available
	data["double_double_room"] = double_room_two_beds_available
	data["special_room"] = special_room_available
	data["selected_room"] = hotel_selected_room
	data["duration"] = reservation_duration

	ui = SSnano.try_update_ui(user, src, ui_key, ui, data, force_open)
	if (!ui)
		ui = new(user, src, ui_key, "hotel_terminal.tmpl", "Hotel Reservations Terminal", 390, 500)
		ui.set_initial_data(data)
		ui.open()
		ui.set_auto_update(1)

/obj/machinery/hotel_terminal/OnTopic(var/mob/user, var/list/href_list, state)

	if (href_list["return_to_main"])
		if(program_mode > 1)
			if(alert("This will erase the reservation. Are you sure?",,"Yes","No")=="No")
				return TOPIC_REFRESH
			deltimer(timeout_timer_id)
			if(selected_room)
				selected_room.clear_reservation(terminal_clear = 1)
		program_mode = 1
		selected_room = null
		flick_screen(screen_icon_state = "hotel_terminal_loading")
		return TOPIC_REFRESH

	if (href_list["return_to_room"])
		if(selected_room && auto_mode)
			program_mode = 2
		return TOPIC_REFRESH
	if (href_list["room_reserve"])
		for(var/datum/hotel_room/R in GLOB.hotel_rooms)

			switch(text2num(href_list["room_reserve"]))
				if(1)
					if(R.guest_count == 1 && !R.special_room && R.room_status == 1)
						selected_room = R
						break
				if(2)
					if(R.guest_count == 2 && R.bed_count == 1 && !R.special_room && R.room_status == 1)
						selected_room = R
						break
				if(3)
					if(R.guest_count == 2 && R.bed_count == 2 && !R.special_room && R.room_status == 1)
						selected_room = R
						break

		if(selected_room)
			reservation_duration = 1
			selected_room.room_status = 2
			selected_room.room_reservation_start_time = station_time_in_ticks
			selected_room.room_reservation_end_time = selected_room.room_reservation_start_time + reservation_duration HOURS
			selected_room.room_log.Add("\[[stationtime2text()]\] Room reservation process was initiated in a guest terminal. Room not available.")
			timeout_timer_id = addtimer(CALLBACK(src, /obj/machinery/hotel_terminal/proc/give_error), 5 MINUTES, TIMER_UNIQUE|TIMER_STOPPABLE)
			program_mode = 2
			flick_screen(screen_icon_state = "hotel_terminal_loading")
		return TOPIC_REFRESH

	if(href_list["set_duration"])
		reservation_duration = text2num(href_list["set_duration"])
		if(program_mode == 2 && selected_room)
			selected_room.room_reservation_end_time = selected_room.room_reservation_start_time + reservation_duration HOURS
		return TOPIC_REFRESH

	if(href_list["room_cancel"])
		if(!selected_room)
			return TOPIC_REFRESH
		selected_room.clear_reservation(just_reset = 1)
		reservation_duration = 1
		selected_room.room_reservation_start_time = station_time_in_ticks
		selected_room.room_reservation_end_time = selected_room.room_reservation_start_time + reservation_duration HOURS
		return TOPIC_REFRESH

	if(href_list["remove_guest"])
		if(selected_room && program_mode == 2)
			selected_room.remove_guest(href_list["remove_guest"])
		return TOPIC_REFRESH

	if(href_list["add_guest"])
		if(selected_room && program_mode == 2)
			program_mode = 3
			flick_screen("hotel_terminal_loading")
		return TOPIC_REFRESH

/obj/machinery/hotel_terminal/proc/give_error(var/terminal_reset = 0)
	if(selected_room)
		if(selected_room.room_status == 3)
			program_mode = 1
			selected_room = null
		else
			selected_room.clear_reservation(auto_clear = 1, terminal_clear = terminal_reset)
			selected_room = null
	if(timeout_timer_id)
		deltimer(timeout_timer_id)
		timeout_timer_id = null
	flick_screen(screen_icon_state = "hotel_terminal_loading")
	program_mode = 0

// PLACEHOLDERS - REMOVE - SHALL REPORT TO THE MASTER UPON DESTRUCTION

/obj/machinery/computer/hotel_room_controller
	var/datum/hotel_room/hotel_room