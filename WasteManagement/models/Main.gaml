/** 

* Name: NewModel 

* Based on the internal empty template.  

* Author: Tran Thi Mai Hoa 

* Tags:  

*/
model NewModel

global {
	geometry shape <- envelope(quanlechan3110_shape_file);
	shape_file quanlechan3110_shape_file <- shape_file("../includes/mapTP_clean.shp");
	graph road_network;
	list<recyclebin> tocollect <- [];
	recyclebin source;
	map<road, float> road_weights;
	bool changeRoad <- false parameter: true;
	bool block_flood <- false;
	int rushhour_gap <- 200;
	int rushhour_duration <- 400;
	int cycle_end <- 0;
	int cnt <- 0;
	bool jam <- false;

	init {
		create road from: quanlechan3110_shape_file with: [rname::get("rname"), beta::int(get("beta")), water::int(get("water"))] {
			if (block_flood) {
				if (beta = 4) {
					do die;
				}

			}

		}

		road_weights <- road as_map (each::float(each.shape.perimeter));
		road_network <- as_edge_graph(road) with_weights road_weights;
		road_network <- road_network with_shortest_path_algorithm #AStar;
		create recyclebin from: csv_file("../includes/LE-CHAN 2.xlsx - Sheet1.csv", true) with:
		[lat::float(get("lat")), lon::float(get("lon")), manual_cart::int(get("note")), address::string(get("addresss"))] {
			location <- to_GAMA_CRS({lon, lat}, "4326").location;
			volume <- manual_cart * 300;
			if (not (location overlaps world.shape)) {
				do die;
			}

		}

		source <- first(recyclebin where (each.name = "recyclebin0"));
		tocollect <- recyclebin where (each.name != "recyclebin0");
		create truck number: 3 {
			location <- source.location;
			max_capacity <- 12000;
			mySpeed <- 40.0 + rnd(10.0);
			roads_knowledge <- road_weights;
		}

		create truck number: 2 {
			location <- source.location;
			max_capacity <- 9000;
			mySpeed <- 45.0 + rnd(10.0);
			roads_knowledge <- road_weights;
		}

		create truck number: 1 {
			location <- source.location;
			max_capacity <- 4000;
			mySpeed <- 45.0 + rnd(10.0);
			roads_knowledge <- road_weights;
		}

	}

	reflex daytime {
		cnt <- cnt + 1;
		if (jam and cnt > rushhour_duration) {
			jam <- false;
			cnt <- 0;
		}

		if (not jam and cnt > rushhour_gap) {
			jam <- true;
			cnt <- 0;
		}

		road_weights <- road as_map (each::each.shape.perimeter * (jam ? each.beta : 1.0));
		road_network <- road_network with_weights road_weights;
		if (changeRoad) {
			ask truck {
				roads_knowledge <- road_weights;
			}

		}

	}

	reflex pausing when: (cycle_end = 0) and ((tocollect count (each.volume > 0)) = 0) and ((truck count (each.capacity > 0)) = 0) {
		cycle_end <- cycle;
		save truck to: "../result/output.csv" format: "csv";
		ask truck {
			save reststop to: "../result/truck" + int(self) + ".csv" format: "csv" header: false;
		}

		//		do pause;
	}

}

species truck skills: [moving] {
	recyclebin current_target;
	int max_capacity <- 12000;
	int capacity <- 0;
	int total_cycle <- 0;
	float mySpeed <- 10.0;
	int count_comeback <- 0;
	int count_comeback_notfull <- 0;
	int count_comeback_full <- 0;
	int max_comeback <- 5;
	int max_total_cycle <- 1000;
	float total_distance <- 0.0;
	string reststop <- "";
	map<road, float> roads_knowledge;
	path path_to_follow;

	reflex choseTarget when: (current_target = nil) {
		if (capacity < max_capacity) {
			current_target <- (tocollect where (each.collector = nil and each.volume > 0)) closest_to self;
			if (current_target = nil) {
				current_target <- source;
			}

			current_target.collector <- self;
		} else {
			current_target <- source;
		}

	}

	geometry old_path <- nil;
	int last_beta <- 1;

	reflex goto when: current_target != nil {
		if (old_path != nil) {
			last_beta <- (jam) ? road(old_path).beta : 1;
		}

		if (path_to_follow = nil) {

		//Find the shortest path using the agent's own weights to compute the shortest path
			path_to_follow <- path_between(road_network with_weights roads_knowledge, location, current_target);
		}
		//the agent follows the path it computed but with the real weights of the graph
		do follow path: path_to_follow speed: mySpeed / (last_beta); //move_weights: road_weights;

		//		if (changeRoad) {
		//			do goto on: road_network target: current_target speed: mySpeed / last_beta move_weights: road_weights;
		//		} else {
		//			do goto on: road_network target: current_target speed: mySpeed / last_beta recompute_path:false;
		//		}
		if (old_path != current_edge and current_edge != nil) {
		//			write current_edge;
			total_distance <- total_distance + current_edge.perimeter;
			old_path <- current_edge;
		}

		if (location = current_target.location) {
			path_to_follow <- nil;
			if (old_path != nil) {
				reststop <- reststop + ("" + road(old_path).rname + "," + cycle + "\n");
				old_path <- nil;
			}

			if (current_target = source and capacity > 0) {
				count_comeback <- count_comeback + 1;
				if (capacity < max_capacity) {
					count_comeback_notfull <- count_comeback_notfull + 1;
				}

				if (capacity = max_capacity) {
					count_comeback_full <- count_comeback_full + 1;
				}

				capacity <- 0;
				current_target.collector <- nil;
				current_target <- nil;
			} else {
			/*

				 0/12	2	12
				 2/12	6	10
				 8/12	2	4
				10/12	5	2

				 */
				int collected_capacity <- min([current_target.volume, max_capacity - capacity]);
				capacity <- capacity + collected_capacity;
				current_target.volume <- current_target.volume - collected_capacity;
				current_target.collector <- nil;
				current_target <- nil;
			}

		} else {
			total_cycle <- total_cycle + 1;
		}

	}

	aspect default {
		draw circle(max_capacity / 100) color: #green;
		draw "" + int(capacity / max_capacity * 100) + "%" color: #red font: font("Arial", 18, #bold) perspective: true;

		//		draw "" + count_comeback + "" color: #red font: font("Arial", 18, #bold) perspective: true;
	}

}

species road {
	int beta <- 1;
	int water <- 1;
	string rname;

	aspect default {
	//		if (  water > 1) {
	//			draw shape + (beta * 5) color: water > 1 ? #indigo : #grey;
	//		}
		if (jam) {
			draw shape + (beta < 99 ? beta * 5 : 5) color: beta > 1 ? #darkorange : #grey;
		} else {
			draw shape + 5 color: #grey;
		}

	}

}

species recyclebin {
	truck collector;
	string address;
	float lat;
	float lon;
	int manual_cart;
	int volume <- 0;

	reflex pollute {
	}

	aspect default {
		if (self = source) {
			draw square(100) color: #pink;
		}

		if (volume > 0) {
		//				draw triangle(150) color: #blue;
		//			draw "" + volume color: #yellow font: font("Arial", 15, #bold);
			draw square(150) color: #cyan;
		}

	}

}

experiment main type: gui {
//	float minimum_cycle_duration <- 0.01;
	action _init_ {
//		float sseed <- 1.0;
		create simulation with: [changeRoad::false, seed::self.seed];
		create simulation with: [changeRoad::true, seed::self.seed];
	}

	output synchronized: false {
		layout #split parameters: false navigator: false editors: false consoles: false toolbars: false tray: false tabs: false controls: true;
		//		layout parameters: false navigator: false editors: false consoles: false toolbars: false tray: false tabs: false controls: true;
		display main1 type: 3d axes: false background: #black {
			camera 'default' location: {5043.5324, 5134.4178, 12656.3535} target: {5043.5324, 5134.1969, 0.0};
			overlay position: {50 #px, 50 #px} size: {1 #px, 1 #px} background: #black border: #black rounded: false {
				float y <- 500 #px;
				float x <- 10.0;
				draw "Dynamic change road:" + changeRoad + " Ended:" + cycle_end at: {x, y} color: #white font: font("Arial", 15, #bold);
				//							loop o over: truck {
				//					draw "" + o + " came back " + o.count_comeback + " times, not full " + o.count_comeback_notfull + " times" at: {x, y} color: #white font: font("Arial", 15, #bold);
				//					y <- y + 500;
				//					draw "Distances:" + int(o.total_distance / 1000) + " km" + ", duration: " + o.total_cycle + " cycles" at: {x, y} color: #white font: font("Arial", 15, #bold);
				//					y <- y + 500;
				//				} 
			}

			image ("../includes/HP.png") position: {0, 0, -0.0001};
			species road;
			species truck;
			species recyclebin position: {0, 0, 0.000001};
		}

		//		display main2 type: 3d axes: false background: #black {
		//			graphics stats {
		//				int y <- 0;
		//				loop o over: truck {
		//					draw "" + o + " came back " + o.count_comeback + " times, not full " + o.count_comeback_notfull + " times" at: {500, y} color: #white font: font("Arial", 15, #bold);
		//					y <- y + 500;
		//					draw "Distances:" + int(o.total_distance / 1000) + " km" + ", duration: " + o.total_cycle + " cycles" at: {1000, y} color: #white font: font("Arial", 15, #bold);
		//					y <- y + 500;
		//				}
		//
		//			}
		//
		//		}

	}

} 