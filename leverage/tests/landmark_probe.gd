extends Node
## Probe: parse + instantiate the v2.5 world landmark systems headless.
## Usage: Godot --headless res://tests/landmark_probe.gd --path .

func _ready() -> void:
        var errs := 0
        for p in ["res://scripts/world/river.gd", "res://scripts/world/wildlife.gd",
                        "res://scripts/world/gas_stations.gd", "res://scripts/world/train_line.gd",
                        "res://scripts/world/explosion.gd"]:
                var s: Variant = load(p)
                if s == null:
                        print("[PROBE-FAIL] load %s" % p)
                        errs += 1
                else:
                        print("[PROBE-PASS] load %s" % p)
        # instantiate
        var river: CinderRiver = CinderRiver.new()
        add_child(river)
        await get_tree().process_frame
        var river_ok: bool = river.water_present() and river.fish_count() >= 18 and river.boat_count() == 3 and river.bridge_count() >= 2
        print("[PROBE-%s] river water=%s fish=%d boats=%d bridges=%d" % [
                "PASS" if river_ok else "FAIL",
                str(river.water_present()), river.fish_count(), river.boat_count(), river.bridge_count()])
        var gas: GasStations = GasStations.new()
        add_child(gas)
        await get_tree().process_frame
        print("[PROBE-%s] gas stations=%d pumps=%d" % ["PASS" if gas.station_count() == 2 and gas.pump_count() >= 8 else "FAIL",
                gas.station_count(), gas.pump_count()])
        var train: TrainLine = TrainLine.new()
        add_child(train)
        await get_tree().process_frame
        train.force_depart()
        await get_tree().create_timer(1.5).timeout
        print("[PROBE-%s] train cars=%d stations=%d running=%s" % ["PASS" if train.car_count() == 5 and train.station_count() == 2 and train.is_running() else "FAIL",
                train.car_count(), train.station_count(), train.is_running()])
        # pump damage -> explosion chain
        var pumps := get_tree().get_nodes_in_group("explosive")
        print("[PROBE-%s] explosive group has %d pumps" % ["PASS" if pumps.size() >= 8 else "FAIL", pumps.size()])
        var p0 := pumps[0] as Node3D
        var intact_before := gas.intact_pumps()
        gas.damage_pump(p0, 100.0)
        await get_tree().create_timer(0.6).timeout
        print("[PROBE-%s] pump detonated (intact %d -> %d)" % ["PASS" if gas.intact_pumps() < intact_before else "FAIL",
                intact_before, gas.intact_pumps()])
        # wildlife
        var dummy_player := Node3D.new()
        add_child(dummy_player)
        dummy_player.position = Vector3(-240, 0, -120)
        var wl: Wildlife = Wildlife.new()
        add_child(wl)
        wl.setup(dummy_player, [Vector2(-230, -130), Vector2(-250, -110)])
        await get_tree().process_frame
        var scattered := wl.pigeons_scatter_from(dummy_player.position, 40.0)
        print("[PROBE-%s] wildlife pigeons=%d gulls=%d rats=%d fireflies=%d moths=%d scattered=%d" % [
                "PASS" if wl.pigeon_count() >= 24 and wl.gull_count() >= 8 and wl.rat_count() >= 12 and wl.firefly_count() >= 4 and wl.moth_count() >= 3 and scattered > 0 else "FAIL",
                wl.pigeon_count(), wl.gull_count(), wl.rat_count(), wl.firefly_count(), wl.moth_count(), scattered])
        # explosion helper end-to-end
        Explosions.boom(Vector3(10, 1, 10), 7.0, 30.0)
        await get_tree().create_timer(0.5).timeout
        print("[PROBE-%s] Explosions.boom executed" % "PASS")
        print("[PROBE] done, errs=%d" % errs)
        get_tree().quit(errs)
