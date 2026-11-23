#!/usr/bin/env python3
"""Author the extra LEVERAGE combat animations on the UAL mannequin rig
(kicks, grapples, drunken style, counters, guard) as new Blender actions,
then export everything to the game's mannequin GLB.

Run: blender --background --python scripts/anim_author.py
"""
import bpy
import math
from mathutils import Euler

DST = "/home/z/my-project/leverage/assets/characters/ual_mannequin.glb"

# keyframe helper -------------------------------------------------------------


def arm():
    for o in bpy.data.objects:
        if o.type == 'ARMATURE':
            return o
    return None


def key(pb, frame):
    pb.keyframe_insert(data_path="location", frame=frame)
    pb.keyframe_insert(data_path="rotation_quaternion", frame=frame)


def rot(pb, frame, euler_deg, loc=None):
    """Set bone pose at frame (euler degrees XYZ) and keyframe it."""
    pb.rotation_mode = 'QUATERNION'
    if loc is not None:
        pb.location = loc
    e = Euler((math.radians(euler_deg[0]), math.radians(euler_deg[1]), math.radians(euler_deg[2])), 'XYZ')
    pb.rotation_quaternion = e.to_quaternion()
    key(pb, frame)


def rest_all(a):
    for pb in a.pose.bones:
        pb.rotation_mode = 'QUATERNION'
        pb.rotation_quaternion = (1.0, 0.0, 0.0, 0.0)
        pb.location = (0.0, 0.0, 0.0)


def make_action(a, name, fps=24):
    act = bpy.data.actions.new(name)
    a.animation_data_create()
    a.animation_data.action = act
    # clear NLA push of old action reference
    for t in list(a.animation_data.nla_tracks):
        a.animation_data.nla_tracks.remove(t)
    rest_all(a)
    return act


def finish(a, name, last_frame):
    """Bake action from the current animation_data action and push to NLA."""
    a.animation_data_create()
    act = a.animation_data.action
    if act:
        act.name = name
        act.use_fake_user = True
        track = a.animation_data.nla_tracks.new()
        track.name = name
        strip = track.strips.new(name, int(1), act)
        strip.frame_start = 1
        strip.frame_end = int(last_frame)
    a.animation_data.action = None


def pb(a, bone):
    return a.pose.bones.get(bone)


# animations ------------------------------------------------------------------

def anim_kick_front(a):
    """Front kick: weight shift, knee up, shin extends, retract. 30f."""
    make_action(a, "Kick_Front")
    L, R = "DEF-thigh.L", "DEF-shin.L"
    spine, hips = "DEF-spine.001", "DEF-spine"
    foot = "DEF-foot.L"
    f = 1
    # start from idle-ish stance
    rot(pb(a, spine), f, (0, 0, 0))
    rot(pb(a, R), f, (0, 0, 0))
    rot(pb(a, L), f, (0, 0, 0))
    rot(pb(a, "DEF-thigh.R"), f, (0, 0, 0))
    rot(pb(a, "DEF-shin.R"), f, (0, 0, 0))
    # wind up: lean back slightly, right leg plants
    rot(pb(a, spine), 4, (-6, 0, 0))
    rot(pb(a, "DEF-thigh.R"), 4, (0, 0, 3))
    # knee raises
    rot(pb(a, L), 8, (-70, 0, 0))
    rot(pb(a, R), 8, (0, 0, 0))  # left shin folded
    rot(pb(a, foot), 8, (20, 0, 0))
    # extend: shin straightens, thigh pushes forward/up
    rot(pb(a, L), 12, (-85, 0, 0))
    rot(pb(a, R), 12, (-8, 0, 0))
    rot(pb(a, foot), 12, (0, 0, 0))
    rot(pb(a, spine), 12, (-10, 0, 0))
    # hold
    rot(pb(a, L), 16, (-88, 0, 0))
    rot(pb(a, R), 16, (-8, 0, 0))
    # retract
    rot(pb(a, L), 22, (-40, 0, 0))
    rot(pb(a, R), 22, (-60, 0, 0))
    rot(pb(a, spine), 22, (-4, 0, 0))
    rot(pb(a, L), 28, (0, 0, 0))
    rot(pb(a, R), 28, (0, 0, 0))
    rot(pb(a, spine), 28, (0, 0, 0))
    finish(a, "Kick_Front", 28)


def anim_kick_round(a):
    """Roundhouse: pivot, hip rotation, leg sweeps horizontally. 32f."""
    make_action(a, "Kick_Round")
    spine, L, R = "DEF-spine.001", "DEF-thigh.L", "DEF-shin.L"
    # wind
    rot(pb(a, spine), 1, (0, 0, 0))
    rot(pb(a, L), 1, (0, 0, 0))
    rot(pb(a, R), 1, (0, 0, 0))
    rot(pb(a, "DEF-spine.002"), 1, (0, 0, 0))
    # chamber: knee up + body turns away
    rot(pb(a, L), 6, (-80, 0, 25))
    rot(pb(a, R), 6, (0, 0, 0))
    rot(pb(a, spine), 6, (0, 0, -25))
    rot(pb(a, "DEF-spine.002"), 6, (0, 0, -12))
    # swing: leg sweeps around (thigh y-rotation), shin extends
    rot(pb(a, L), 12, (-85, -55, 10))
    rot(pb(a, R), 12, (-5, 0, 0))
    rot(pb(a, spine), 12, (0, 0, 20))
    rot(pb(a, "DEF-foot.L"), 12, (0, 0, 0))
    # follow-through
    rot(pb(a, L), 16, (-70, -75, 0))
    rot(pb(a, spine), 16, (0, 0, 35))
    # retract
    rot(pb(a, L), 24, (-30, -20, 5))
    rot(pb(a, spine), 24, (0, 0, 5))
    rot(pb(a, L), 30, (0, 0, 0))
    rot(pb(a, spine), 30, (0, 0, 0))
    rot(pb(a, R), 30, (0, 0, 0))
    finish(a, "Kick_Round", 30)


def anim_kick_push(a):
    """Push kick (kickboxing side kick): knee, thrust, reposition. 26f."""
    make_action(a, "Kick_Push")
    spine, L, R = "DEF-spine.001", "DEF-thigh.L", "DEF-shin.L"
    rot(pb(a, spine), 1, (0, 0, 0))
    rot(pb(a, L), 1, (0, 0, 0))
    rot(pb(a, R), 1, (0, 0, 0))
    # chamber knee slightly in
    rot(pb(a, L), 5, (-60, 15, 0))
    rot(pb(a, R), 5, (0, 0, 0))
    rot(pb(a, spine), 5, (-5, 5, 0))
    # thrust out (foot goes forward)
    rot(pb(a, L), 10, (-80, 20, 0))
    rot(pb(a, R), 10, (-4, 0, 0))
    rot(pb(a, spine), 10, (-8, 8, 0))
    # hold + retract
    rot(pb(a, L), 14, (-82, 20, 0))
    rot(pb(a, L), 20, (-30, 8, 0))
    rot(pb(a, R), 20, (-45, 0, 0))
    rot(pb(a, L), 25, (0, 0, 0))
    rot(pb(a, R), 25, (0, 0, 0))
    rot(pb(a, spine), 25, (0, 0, 0))
    finish(a, "Kick_Push", 25)


def anim_grapple_grab(a):
    """Two-hand grab: reach, clasp, pull. 30f."""
    make_action(a, "Grapple_Grab")
    spine = "DEF-spine.001"
    arms = ["DEF-upper_arm.L", "DEF-upper_arm.R"]
    fores = ["DEF-forearm.L", "DEF-forearm.R"]
    hands = ["DEF-hand.L", "DEF-hand.R"]
    rot(pb(a, spine), 1, (0, 0, 0))
    for s in arms + fores + hands:
        rot(pb(a, s), 1, (0, 0, 0))
    # lunge forward
    rot(pb(a, spine), 6, (18, 0, 0))
    for armn in arms:
        rot(pb(a, armn), 6, (0, 0, -60))  # arms forward-ish (x rot from T)
    for f in fores:
        rot(pb(a, f), 6, (0, 0, -70))
    # clasp (slight inward)
    rot(pb(a, arms[0]), 10, (0, 12, -65))
    rot(pb(a, arms[1]), 10, (0, -12, -65))
    for f in fores:
        rot(pb(a, f), 10, (0, 0, -85))
    # pull toward chest
    rot(pb(a, spine), 16, (8, 0, 0))
    rot(pb(a, arms[0]), 16, (0, 0, -35))
    rot(pb(a, arms[1]), 16, (0, 0, -35))
    for f in fores:
        rot(pb(a, f), 16, (0, 0, -50))
    # settle back
    rot(pb(a, spine), 24, (0, 0, 0))
    for armn in arms + fores + hands:
        rot(pb(a, armn), 24, (0, 0, 0))
    finish(a, "Grapple_Grab", 24)


def anim_grapple_throw(a):
    """Hip throw: dip, twist, straighten hard. 34f."""
    make_action(a, "Grapple_Throw")
    spine1, spine2 = "DEF-spine.001", "DEF-spine.002"
    L, R = "DEF-thigh.L", "DEF-thigh.R"
    rot(pb(a, spine1), 1, (0, 0, 0))
    rot(pb(a, spine2), 1, (0, 0, 0))
    rot(pb(a, L), 1, (0, 0, 0))
    rot(pb(a, R), 1, (0, 0, 0))
    # dip + twist (load the throw)
    rot(pb(a, L), 5, (30, 0, 0))
    rot(pb(a, R), 5, (0, 0, -8))
    rot(pb(a, spine1), 5, (14, 0, -18))
    rot(pb(a, spine2), 5, (6, 0, -12))
    # explode upward: legs extend, body twists through
    rot(pb(a, L), 11, (-12, 0, 10))
    rot(pb(a, R), 11, (0, 0, 20))
    rot(pb(a, spine1), 11, (-6, 0, 22))
    rot(pb(a, spine2), 11, (-4, 0, 30))
    rot(pb(a, "DEF-shin.L"), 11, (-15, 0, 0))
    rot(pb(a, "DEF-shin.R"), 11, (-8, 0, 0))
    # follow through + arms whip
    rot(pb(a, spine1), 16, (-10, 0, 26))
    rot(pb(a, "DEF-upper_arm.L"), 16, (0, 0, -100))
    rot(pb(a, "DEF-upper_arm.R"), 16, (0, 0, -100))
    # recover
    rot(pb(a, spine1), 26, (0, 0, 0))
    rot(pb(a, spine2), 26, (0, 0, 0))
    rot(pb(a, L), 26, (0, 0, 0))
    rot(pb(a, R), 26, (0, 0, 0))
    rot(pb(a, "DEF-upper_arm.L"), 26, (0, 0, 0))
    rot(pb(a, "DEF-upper_arm.R"), 26, (0, 0, 0))
    rot(pb(a, "DEF-shin.L"), 26, (0, 0, 0))
    rot(pb(a, "DEF-shin.R"), 26, (0, 0, 0))
    finish(a, "Grapple_Throw", 26)


def anim_drunken_idle(a):
    """Drunken idle loop: loose sway, head loll, arms dangling. 48f loop."""
    make_action(a, "Drunken_Idle")
    spine1, spine2, neck, head = "DEF-spine.001", "DEF-spine.002", "DEF-neck", "DEF-head"
    aL, aR = "DEF-upper_arm.L", "DEF-upper_arm.R"
    fL, fR = "DEF-forearm.L", "DEF-forearm.R"
    bones = [spine1, spine2, neck, head, aL, aR, fL, fR]
    # sway cycle keyframes
    rot(pb(a, spine1), 1, (4, 0, 5))
    rot(pb(a, spine2), 1, (2, 3, -4))
    rot(pb(a, neck), 1, (-6, 8, 0))
    rot(pb(a, head), 1, (8, 6, -10))
    rot(pb(a, aL), 1, (0, 8, -8))
    rot(pb(a, aR), 1, (0, -8, 8))
    rot(pb(a, fL), 1, (0, 0, -25))
    rot(pb(a, fR), 1, (0, 0, 25))
    # mid sway other direction
    rot(pb(a, spine1), 24, (-3, 0, -6))
    rot(pb(a, spine2), 24, (-2, -3, 5))
    rot(pb(a, neck), 24, (5, -7, 0))
    rot(pb(a, head), 24, (-7, -5, 12))
    rot(pb(a, aL), 24, (0, -6, -10))
    rot(pb(a, aR), 24, (0, 6, 10))
    rot(pb(a, fL), 24, (0, 0, -35))
    rot(pb(a, fR), 24, (0, 0, 35))
    # loop back
    rot(pb(a, spine1), 48, (4, 0, 5))
    rot(pb(a, spine2), 48, (2, 3, -4))
    rot(pb(a, neck), 48, (-6, 8, 0))
    rot(pb(a, head), 48, (8, 6, -10))
    rot(pb(a, aL), 48, (0, 8, -8))
    rot(pb(a, aR), 48, (0, -8, 8))
    rot(pb(a, fL), 48, (0, 0, -25))
    rot(pb(a, fR), 48, (0, 0, 25))
    finish(a, "Drunken_Idle", 48)


def anim_drunken_swing(a):
    """Drunken wild overhead swing: wind wide, flop forward. 28f."""
    make_action(a, "Drunken_Swing")
    spine1, spine2 = "DEF-spine.001", "DEF-spine.002"
    aR, aL = "DEF-upper_arm.R", "DEF-upper_arm.L"
    fR, fL = "DEF-forearm.R", "DEF-forearm.L"
    rot(pb(a, spine1), 1, (0, 0, 0))
    # wild wind-up: body tips back + side, right arm high
    rot(pb(a, spine1), 6, (-14, 0, -12))
    rot(pb(a, spine2), 6, (-8, 0, -8))
    rot(pb(a, aR), 6, (0, 0, 90))
    rot(pb(a, aL), 6, (0, 0, 60))
    rot(pb(a, fR), 6, (0, 0, 40))
    rot(pb(a, fL), 6, (0, 0, 30))
    # lunge forward with the swing
    rot(pb(a, spine1), 12, (26, 0, 8))
    rot(pb(a, spine2), 12, (16, 0, 6))
    rot(pb(a, aR), 12, (0, 0, -95))
    rot(pb(a, aL), 12, (0, 0, -75))
    rot(pb(a, fR), 12, (0, 0, -10))
    rot(pb(a, fL), 12, (0, 0, -5))
    rot(pb(a, "DEF-thigh.L"), 12, (-15, 0, 0))
    rot(pb(a, "DEF-shin.L"), 12, (-25, 0, 0))
    # stumble recovery
    rot(pb(a, spine1), 20, (10, 0, -5))
    rot(pb(a, aR), 20, (0, 0, -30))
    rot(pb(a, aL), 20, (0, 0, -20))
    rot(pb(a, "DEF-thigh.L"), 20, (0, 0, 0))
    rot(pb(a, "DEF-shin.L"), 20, (0, 0, 0))
    rot(pb(a, spine1), 26, (0, 0, 0))
    rot(pb(a, spine2), 26, (0, 0, 0))
    rot(pb(a, aR), 26, (0, 0, 0))
    rot(pb(a, aL), 26, (0, 0, 0))
    rot(pb(a, fR), 26, (0, 0, 0))
    rot(pb(a, fL), 26, (0, 0, 0))
    finish(a, "Drunken_Swing", 26)


def anim_drunken_sway(a):
    """Drunken evade sway: quick duck-lurch sideways. 16f."""
    make_action(a, "Drunken_Sway")
    spine1, spine2 = "DEF-spine.001", "DEF-spine.002"
    L, R = "DEF-thigh.L", "DEF-thigh.R"
    rot(pb(a, spine1), 1, (0, 0, 0))
    rot(pb(a, spine2), 1, (0, 0, 0))
    rot(pb(a, L), 1, (0, 0, 0))
    rot(pb(a, R), 1, (0, 0, 0))
    # lurch: duck + lean hard to the right
    rot(pb(a, spine1), 6, (14, 0, -18))
    rot(pb(a, spine2), 6, (8, 0, -12))
    rot(pb(a, L), 6, (22, 0, 0))
    rot(pb(a, "DEF-shin.L"), 6, (35, 0, 0))
    # return
    rot(pb(a, spine1), 13, (0, 0, 0))
    rot(pb(a, spine2), 13, (0, 0, 0))
    rot(pb(a, L), 13, (0, 0, 0))
    rot(pb(a, "DEF-shin.L"), 13, (0, 0, 0))
    finish(a, "Drunken_Sway", 13)


def anim_counter_trip(a):
    """Counter: sidestep + leg sweep trip. 24f."""
    make_action(a, "Counter_Trip")
    spine1 = "DEF-spine.001"
    L, R = "DEF-thigh.L", "DEF-thigh.R"
    sL = "DEF-shin.L"
    rot(pb(a, spine1), 1, (0, 0, 0))
    rot(pb(a, L), 1, (0, 0, 0))
    rot(pb(a, R), 1, (0, 0, 0))
    rot(pb(a, sL), 1, (0, 0, 0))
    # sidestep twist
    rot(pb(a, spine1), 5, (0, 0, 25))
    rot(pb(a, R), 5, (0, 0, 15))
    # sweep: left leg low sweep across
    rot(pb(a, L), 10, (25, -35, 0))
    rot(pb(a, sL), 10, (5, 0, 0))
    rot(pb(a, spine1), 10, (10, 0, 30))
    # follow
    rot(pb(a, L), 14, (15, -55, 0))
    # recover
    rot(pb(a, L), 20, (0, 0, 0))
    rot(pb(a, sL), 20, (0, 0, 0))
    rot(pb(a, spine1), 20, (0, 0, 0))
    rot(pb(a, R), 20, (0, 0, 0))
    finish(a, "Counter_Trip", 20)


def anim_guard(a):
    """Fighting guard: hands up bobbing loop. 24f."""
    make_action(a, "Guard_Idle")
    spine1 = "DEF-spine.001"
    aL, aR = "DEF-upper_arm.L", "DEF-upper_arm.R"
    fL, fR = "DEF-forearm.L", "DEF-forearm.R"
    rot(pb(a, spine1), 1, (6, 0, 0))
    rot(pb(a, aL), 1, (0, 0, -55))
    rot(pb(a, aR), 1, (0, 0, 55))
    rot(pb(a, fL), 1, (0, 0, -95))
    rot(pb(a, fR), 1, (0, 0, 95))
    # bob
    rot(pb(a, spine1), 12, (8, 0, 2))
    rot(pb(a, fL), 12, (0, 0, -85))
    rot(pb(a, fR), 12, (0, 0, 85))
    rot(pb(a, spine1), 24, (6, 0, 0))
    rot(pb(a, fL), 24, (0, 0, -95))
    rot(pb(a, fR), 24, (0, 0, 95))
    finish(a, "Guard_Idle", 24)


def anim_aim_walk(a):
    """Strafe/aim walk compact loop (slow shuffle). 24f."""
    make_action(a, "Aim_Walk")
    L, R = "DEF-thigh.L", "DEF-thigh.R"
    sL, sR = "DEF-shin.L", "DEF-shin.R"
    spine1 = "DEF-spine.001"
    rot(pb(a, spine1), 1, (2, 0, 0))
    rot(pb(a, L), 1, (0, 0, 0))
    rot(pb(a, R), 1, (0, 0, 0))
    rot(pb(a, sL), 1, (0, 0, 0))
    rot(pb(a, sR), 1, (0, 0, 0))
    rot(pb(a, L), 6, (-18, 0, 0))
    rot(pb(a, sL), 6, (-25, 0, 0))
    rot(pb(a, R), 6, (10, 0, 0))
    rot(pb(a, sR), 6, (15, 0, 0))
    rot(pb(a, L), 12, (-8, 0, 0))
    rot(pb(a, sL), 12, (-10, 0, 0))
    rot(pb(a, R), 12, (5, 0, 0))
    rot(pb(a, sR), 12, (8, 0, 0))
    rot(pb(a, L), 18, (-18, 0, 0))
    rot(pb(a, sL), 18, (-25, 0, 0))
    rot(pb(a, R), 18, (10, 0, 0))
    rot(pb(a, sR), 18, (15, 0, 0))
    rot(pb(a, L), 24, (0, 0, 0))
    rot(pb(a, sL), 24, (0, 0, 0))
    rot(pb(a, R), 24, (0, 0, 0))
    rot(pb(a, sR), 24, (0, 0, 0))
    finish(a, "Aim_Walk", 24)


def main():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=DST)
    a = arm()
    print("ANIMAUTH armature:", a.name, "bones:", len(a.data.bones))
    anim_kick_front(a)
    anim_kick_round(a)
    anim_kick_push(a)
    anim_grapple_grab(a)
    anim_grapple_throw(a)
    anim_drunken_idle(a)
    anim_drunken_swing(a)
    anim_drunken_sway(a)
    anim_counter_trip(a)
    anim_guard(a)
    anim_aim_walk(a)
    print("ANIMAUTH actions now:", len(bpy.data.actions))
    print("ANIMAUTH new:", [x.name for x in bpy.data.actions if x.name in
          ("Kick_Front", "Kick_Round", "Kick_Push", "Grapple_Grab", "Grapple_Throw",
           "Drunken_Idle", "Drunken_Swing", "Drunken_Sway", "Counter_Trip", "Guard_Idle", "Aim_Walk")])
    bpy.ops.export_scene.gltf(
        filepath=DST,
        export_format='GLB',
        export_yup=True,
        export_apply=False,
        export_materials='EXPORT',
        export_animations=True,
        export_animation_mode='ACTIONS',
        export_extras=False,
        export_cameras=False,
        export_lights=False,
        export_force_sampling=True,
        export_optimize_animation_size=False,
    )
    print("ANIMAUTH exported ->", DST)


main()
