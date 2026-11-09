extends Node3D
# Prototipo local: no incluye multiplayer ni modelos oficiales.
const TYPES := ["Arcanine", "Milotic", "Grovyle", "Pikachu", "Glaceon", "Seviper", "Gabite", "Darkrai", "Lucario", "Staraptor"]
const COLORS := [Color.ORANGE_RED, Color.DODGER_BLUE, Color.FOREST_GREEN, Color.YELLOW, Color.LIGHT_CYAN, Color.PURPLE, Color.SANDY_BROWN, Color.DARK_SLATE_BLUE, Color.STEEL_BLUE, Color.WHITE_SMOKE]
var hero: CharacterBody3D
var camera: Camera3D
var hud: CanvasLayer
var menu: Control
var battle_ui: Control
var current_type := 0
var hp := 250
var kills := 0
var deaths := 0
var active := false
var cooldowns := {"Q":0.0,"E":0.0,"F":0.0}
var joystick := Vector2.ZERO
var touch_origin := Vector2.ZERO
var touch_id := -1
var shots: Array[Dictionary] = []
var match_time := 900.0
var status_label: Label
var timer_label: Label
var health_label: Label
var name_label: Label
var selected_label: Label
var environment: Node3D
var character_visual: MeshInstance3D
var particles: Array[Dictionary] = []
var aim_direction := Vector3.FORWARD
var visual_root: Node3D
var quality := "equilibrada"

func _ready() -> void:
    _setup_world()
    _setup_ui()
    _show_menu()

func _mat(c: Color, emission := false) -> StandardMaterial3D:
    var m := StandardMaterial3D.new()
    m.albedo_color = c
    m.roughness = 0.8
    if emission:
        m.emission_enabled = true
        m.emission = c
        m.emission_energy_multiplier = 2.0
    return m

func _box(parent: Node3D, size: Vector3, p: Vector3, color: Color, collision := false) -> MeshInstance3D:
    var mesh := MeshInstance3D.new()
    var shape := BoxMesh.new()
    shape.size = size
    mesh.mesh = shape
    mesh.material_override = _mat(color)
    mesh.position = p
    parent.add_child(mesh)
    if collision:
        var body := StaticBody3D.new()
        body.position = p
        parent.add_child(body)
        var col := CollisionShape3D.new()
        var bs := BoxShape3D.new()
        bs.size = size
        col.shape = bs
        body.add_child(col)
    return mesh

func _setup_world() -> void:
    environment = Node3D.new()
    environment.name = "Arena3D"
    add_child(environment)
    _box(environment, Vector3(300, 1, 300), Vector3(0, -0.55, 0), Color(0.26,0.38,0.24), true)
    var sun := DirectionalLight3D.new()
    sun.rotation_degrees = Vector3(-52,-35,0)
    sun.light_energy = 1.2
    add_child(sun)
    var world := WorldEnvironment.new()
    var env := Environment.new()
    env.background_mode = Environment.BG_COLOR
    env.background_color = Color(0.55,0.75,0.92)
    env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
    env.ambient_light_color = Color(0.65,0.72,0.8)
    env.ambient_light_energy = 0.6
    world.environment = env
    add_child(world)
    # Biomas decorativos y materiales animados.
    _build_landscape()
    # Zonas decorativas con geometría simple y costes bajos para GPU integrada.
    _box(environment, Vector3(66,0.15,66), Vector3(-91,0.02,-91), Color(0.17,0.48,0.2))
    _box(environment, Vector3(66,0.15,66), Vector3(91,0.02,-91), Color(0.3,0.24,0.22))
    _box(environment, Vector3(66,0.15,66), Vector3(-91,0.02,91), Color(0.55,0.8,0.88))
    _box(environment, Vector3(66,0.15,66), Vector3(91,0.02,91), Color(0.48,0.42,0.32))
    _box(environment, Vector3(48,0.08,35), Vector3(85,0.16,-90), Color(1.0,0.18,0.025))
    _box(environment, Vector3(55,0.08,34), Vector3(-88,0.16,91), Color(0.1,0.48,0.78))
    var rng := RandomNumberGenerator.new()
    rng.seed = 24680
    for i in range(130):
        var x := rng.randf_range(-144,144)
        var z := rng.randf_range(-144,144)
        if absf(x)<15 and absf(z)<15:
            continue
        if x < -55 and z < -55:
            _box(environment, Vector3(1.1, rng.randf_range(3,6),1.1), Vector3(x,2.2,z), Color(0.34,0.22,0.12))
            _box(environment, Vector3(4,4,4), Vector3(x,5.2,z), Color(0.12,0.38,0.15))
        elif x > 55 and z > 55:
            _box(environment, Vector3(rng.randf_range(2,5),rng.randf_range(1,4),2.2), Vector3(x,1.4,z), Color(0.47,0.47,0.43))
        else:
            _box(environment, Vector3(1.5,0.6,1.5), Vector3(x,0.3,z), Color(0.27,0.42,0.22))
    hero = CharacterBody3D.new()
    hero.name = "Jugador"
    hero.position = Vector3(0,1,0)
    add_child(hero)
    var collision := CollisionShape3D.new()
    var capsule := CapsuleShape3D.new()
    capsule.radius = 0.55
    capsule.height = 2.0
    collision.shape = capsule
    hero.add_child(collision)
    visual_root = Node3D.new()
    hero.add_child(visual_root)
    character_visual = MeshInstance3D.new()
    character_visual.mesh = CapsuleMesh.new()
    character_visual.material_override = _mat(COLORS[current_type])
    _build_creature_visual()
    visual_root.add_child(character_visual)
    _build_creature_visual()
    camera = Camera3D.new()
    camera.current = true
    camera.position = Vector3(0,26,25)
    camera.rotation_degrees = Vector3(-43,0,0)
    add_child(camera)

func _label(parent: Control, txt: String, pos: Vector2, size: Vector2, font_size := 20) -> Label:
    var l := Label.new()
    l.text = txt
    l.position = pos
    l.size = size
    l.add_theme_font_size_override("font_size", font_size)
    parent.add_child(l)
    return l

func _button(parent: Control, txt: String, pos: Vector2, size: Vector2, action: Callable) -> Button:
    var b := Button.new()
    b.text = txt
    b.position = pos
    b.size = size
    b.pressed.connect(action)
    parent.add_child(b)
    return b

func _setup_ui() -> void:
    hud = CanvasLayer.new()
    add_child(hud)
    menu = Control.new()
    menu.set_anchors_preset(Control.PRESET_FULL_RECT)
    hud.add_child(menu)
    var bg := ColorRect.new()
    bg.color = Color(0.035,0.06,0.12,0.96)
    bg.set_anchors_preset(Control.PRESET_FULL_RECT)
    menu.add_child(bg)
    _label(menu,"POKÉMON  BATTLE  ARENA",Vector2(285,104),Vector2(850,70),45)
    _label(menu,"EDICIÓN NATIVA · BIOMAS 3D · ANDROID / PC",Vector2(375,189),Vector2(720,45),20)
    selected_label = _label(menu,"Personaje: Arcanine",Vector2(480,295),Vector2(500,40),24)
    _button(menu,"◀ Anterior",Vector2(370,360),Vector2(180,65),func(): _change_type(-1))
    _button(menu,"Siguiente ▶",Vector2(700,360),Vector2(180,65),func(): _change_type(1))
    _button(menu,"ENTRAR A LA ARENA",Vector2(445,475),Vector2(390,75),_start_match)
    _label(menu,"Demo visual · Modelos oficiales y multijugador pendientes",Vector2(360,580),Vector2(700,30),17)
    battle_ui = Control.new()
    battle_ui.set_anchors_preset(Control.PRESET_FULL_RECT)
    hud.add_child(battle_ui)
    name_label = _label(battle_ui,"Arcanine",Vector2(20,14),Vector2(300,35),25)
    health_label = _label(battle_ui,"HP: 250 / 250",Vector2(20,55),Vector2(300,35),22)
    timer_label = _label(battle_ui,"15:00",Vector2(600,14),Vector2(180,45),30)
    status_label = _label(battle_ui,"Q  E  F",Vector2(20,95),Vector2(550,35),18)
    _button(battle_ui,"MENÚ",Vector2(1100,12),Vector2(145,55),_show_menu)
    _button(battle_ui,"Q",Vector2(895,575),Vector2(95,95),func(): _attack("Q"))
    _button(battle_ui,"E",Vector2(1000,575),Vector2(95,95),func(): _attack("E"))
    _button(battle_ui,"F",Vector2(1105,575),Vector2(95,95),func(): _attack("F"))
    _label(battle_ui,"◉ MOVER",Vector2(65,580),Vector2(180,45),24)
    _button(battle_ui,"AGILIDAD",Vector2(700,603),Vector2(150,54),_dash)

func _change_type(delta: int) -> void:
    current_type = posmod(current_type+delta,TYPES.size())
    selected_label.text = "Personaje: " + TYPES[current_type]
    character_visual.material_override = _mat(COLORS[current_type])
    _build_creature_visual()

func _show_menu() -> void:
    active = false
    menu.visible = true
    battle_ui.visible = false

func _start_match() -> void:
    hp = 250
    match_time = 900.0
    cooldowns = {"Q":0.0,"E":0.0,"F":0.0}
    hero.position = Vector3(0,1,0)
    active = true
    menu.visible = false
    battle_ui.visible = true
    name_label.text = TYPES[current_type]

func _process(delta: float) -> void:
    if not active:
        return
    match_time = maxf(0,match_time-delta)
    timer_label.text = "%02d:%02d" % [int(match_time / 60.0),int(match_time)%60]
    health_label.text = "HP: %d / 250" % hp
    for k in cooldowns.keys():
        cooldowns[k] = maxf(0,cooldowns[k]-delta)
    status_label.text = "Q: %.1f s   E: %.1f s   F: %.1f s" % [cooldowns["Q"],cooldowns["E"],cooldowns["F"]]
    if match_time <= 0:
        _show_menu()
    _update_particles(delta)
    for i in range(shots.size()-1,-1,-1):
        var shot: Dictionary = shots[i]
        if not is_instance_valid(shot.node):
            shots.remove_at(i)
            continue
        shot.node.position += shot.direction * shot.speed * delta
        shot.node.rotate_y(delta * 4.0)
        if randi() % 3 == 0:
            _spark(shot.node.global_position, COLORS[current_type], 0.25)
        shot.life -= delta
        if shot.life <= 0:
            shot.node.queue_free()
            shots.remove_at(i)
        else:
            shots[i] = shot
    camera.position = camera.position.lerp(hero.position+Vector3(0,26,25),minf(1,delta*7))

func _physics_process(delta: float) -> void:
    if not active:
        return
    var axis := Input.get_vector("move_left","move_right","move_forward","move_back")
    if joystick.length() > 0.1:
        axis = joystick
    var direction := Vector3(axis.x,0,axis.y).normalized()
    hero.velocity.x = direction.x*7.0
    hero.velocity.z = direction.z*7.0
    if direction.length() > 0.05:
        aim_direction = direction
        visual_root.rotation.y = lerp_angle(visual_root.rotation.y, atan2(-direction.x, -direction.z), minf(1.0,delta*12.0))
    hero.velocity.y = -2.0
    hero.move_and_slide()
    hero.position.x = clampf(hero.position.x,-148,148)
    hero.position.z = clampf(hero.position.z,-148,148)

func _unhandled_input(event: InputEvent) -> void:
    if not active:
        return
    if event.is_action_pressed("attack_q"):
        _attack("Q")
    if event.is_action_pressed("attack_e"):
        _attack("E")
    if event.is_action_pressed("attack_f"):
        _attack("F")
    if event is InputEventScreenTouch:
        if event.pressed and event.position.x < get_viewport().get_visible_rect().size.x*0.4:
            touch_id = event.index
            touch_origin = event.position
        elif not event.pressed and event.index == touch_id:
            touch_id = -1
            joystick = Vector2.ZERO
    elif event is InputEventScreenDrag and event.index == touch_id:
        joystick = (event.position-touch_origin).limit_length(100)/100.0

func _attack(key: String) -> void:
    if not active or cooldowns[key]>0:
        return
    cooldowns[key] = {"Q":4.0,"E":8.0,"F":30.0}[key]
    var projectile := MeshInstance3D.new()
    var sphere := SphereMesh.new()
    sphere.radius = 0.4 if key != "F" else 0.9
    sphere.height = sphere.radius*2
    projectile.mesh = sphere
    projectile.material_override = _mat(COLORS[current_type],true)
    projectile.position = hero.position+Vector3(0,0.8,0)+aim_direction*1.5
    add_child(projectile)
    var speed := 38.0 if key != "F" else 26.0
    shots.append({"node":projectile,"direction":aim_direction,"speed":speed,"life":2.0})
    for j in range(14 if key == "F" else 7):
        _spark(projectile.position, COLORS[current_type], 0.65 if key == "F" else 0.35)


# Geometría instanciada para reducir llamadas de dibujo en Android.
func _scatter_mesh(mesh: Mesh, mat: Material, transforms: Array[Transform3D]) -> void:
    var multi := MultiMesh.new()
    multi.transform_format = MultiMesh.TRANSFORM_3D
    multi.mesh = mesh
    multi.instance_count = transforms.size()
    for i in range(transforms.size()):
        multi.set_instance_transform(i, transforms[i])
    var node := MultiMeshInstance3D.new()
    node.multimesh = multi
    node.material_override = mat
    environment.add_child(node)

func _animated_surface(color_a: Color, color_b: Color, liquid: bool) -> ShaderMaterial:
    var shader := Shader.new()
    shader.code = """shader_type spatial;
render_mode cull_disabled, diffuse_lambert, specular_disabled;
uniform vec4 tone_a : source_color = vec4(0.04,0.37,0.75,1.0);
uniform vec4 tone_b : source_color = vec4(0.13,0.69,0.9,1.0);
uniform float speed = 1.0;
void vertex() { VERTEX.y += sin(VERTEX.x * 0.21 + TIME * speed) * cos(VERTEX.z * 0.19 + TIME * speed) * 0.10; }
void fragment() { float ripple = sin(UV.x * 50.0 + TIME * speed) * cos(UV.y * 45.0 - TIME * speed); ALBEDO = mix(tone_a.rgb, tone_b.rgb, 0.5 + ripple * 0.25); ROUGHNESS = 0.28; EMISSION = tone_b.rgb * 0.22; }
"""
    var mat := ShaderMaterial.new()
    mat.shader = shader
    mat.set_shader_parameter("tone_a",color_a)
    mat.set_shader_parameter("tone_b",color_b)
    mat.set_shader_parameter("speed", 1.8 if liquid else 0.9)
    return mat

func _build_landscape() -> void:
    var rng := RandomNumberGenerator.new()
    rng.seed = 20261109
    # Agua y lava con ondulación suave. Son superficies decorativas, no simulación física.
    var water := _box(environment, Vector3(56,0.16,34), Vector3(-88,0.24,91), Color(0.03,0.5,0.8))
    water.material_override = _animated_surface(Color(0.015,0.17,0.38), Color(0.08,0.7,0.91), true)
    var lava := _box(environment, Vector3(49,0.16,35), Vector3(85,0.24,-90), Color(1.0,0.2,0.01))
    lava.material_override = _animated_surface(Color(0.55,0.035,0.005), Color(1.0,0.39,0.012), true)
    # Pasto: miles de instancias comparten una sola malla.
    var grass := BoxMesh.new()
    grass.size = Vector3(0.11,0.52,0.09)
    var grass_instances: Array[Transform3D] = []
    for i in range(1900):
        var x := rng.randf_range(-145,145)
        var z := rng.randf_range(-145,145)
        if (x > 58 and x < 114 and z < -72 and z > -108) or (x < -59 and x > -117 and z > 74 and z < 108):
            continue
        var t := Transform3D.IDENTITY
        t.origin = Vector3(x,0.29,z)
        t.basis = Basis(Vector3.UP, rng.randf_range(0,TAU)).scaled(Vector3(0.8,rng.randf_range(0.6,1.6),0.8))
        grass_instances.append(t)
    _scatter_mesh(grass,_mat(Color(0.22,0.58,0.17)),grass_instances)
    # Rocas de distintos tamaños y orientación.
    var rock := SphereMesh.new()
    rock.radius = 1.0
    rock.height = 2.0
    rock.radial_segments = 8
    rock.rings = 4
    var rock_instances: Array[Transform3D] = []
    for i in range(170):
        var t := Transform3D.IDENTITY
        t.origin = Vector3(rng.randf_range(-140,140),0.1,rng.randf_range(-140,140))
        t.basis = Basis(Vector3.UP,rng.randf_range(0,TAU)).scaled(Vector3(rng.randf_range(0.5,2.3),rng.randf_range(0.35,1.7),rng.randf_range(0.6,2.1)))
        rock_instances.append(t)
    _scatter_mesh(rock,_mat(Color(0.38,0.39,0.36)),rock_instances)
    # Arbolado low-poly: troncos y copas independientes, instanciados.
    var trunk := CylinderMesh.new()
    trunk.top_radius = 0.38
    trunk.bottom_radius = 0.56
    trunk.height = 5.0
    var canopy := SphereMesh.new()
    canopy.radius = 2.6
    canopy.height = 5.2
    canopy.radial_segments = 10
    canopy.rings = 6
    var trunks: Array[Transform3D] = []
    var crowns: Array[Transform3D] = []
    for i in range(110):
        var x := rng.randf_range(-145,-54)
        var z := rng.randf_range(-145,-55)
        var scale := rng.randf_range(0.75,1.35)
        var t := Transform3D.IDENTITY
        t.origin = Vector3(x,2.5*scale,z)
        t.basis = Basis.IDENTITY.scaled(Vector3(scale,scale,scale))
        trunks.append(t)
        t.origin.y = 6.2*scale
        crowns.append(t)
    _scatter_mesh(trunk,_mat(Color(0.3,0.19,0.11)),trunks)
    _scatter_mesh(canopy,_mat(Color(0.08,0.35,0.15)),crowns)
    # Columnas de piedra en las ruinas.
    for i in range(16):
        var x := 68.0 + float(i % 4) * 12.0
        var z := 65.0 + float(i / 4) * 12.0
        _box(environment,Vector3(2.4,rng.randf_range(4,9),2.4),Vector3(x,3,z),Color(0.45,0.43,0.39),true)

func _build_creature_visual() -> void:
    # Criatura estilizada ORIGINAL de prueba; no es un modelo oficial de Pokémon.
    for child in visual_root.get_children():
        if child != character_visual:
            child.queue_free()
    var body_color := COLORS[current_type]
    var head := MeshInstance3D.new()
    var head_mesh := SphereMesh.new()
    head_mesh.radius = 0.43
    head_mesh.height = 0.85
    head.mesh = head_mesh
    head.material_override = _mat(body_color.lightened(0.18))
    head.position = Vector3(0,0.86,-0.18)
    visual_root.add_child(head)
    for side in [-1.0,1.0]:
        var ear := MeshInstance3D.new()
        var ear_mesh := BoxMesh.new()
        ear_mesh.size = Vector3(0.27,0.62,0.35)
        ear.mesh = ear_mesh
        ear.position = Vector3(side*0.3,1.43,-0.15)
        ear.material_override = _mat(body_color.darkened(0.13))
        visual_root.add_child(ear)
        var eye := MeshInstance3D.new()
        var eye_mesh := SphereMesh.new()
        eye_mesh.radius = 0.09
        eye_mesh.height = 0.18
        eye.mesh = eye_mesh
        eye.position = Vector3(side*0.19,0.96,-0.53)
        eye.material_override = _mat(Color(0.03,0.04,0.08))
        visual_root.add_child(eye)

func _spark(origin: Vector3, tint: Color, lifetime: float) -> void:
    if particles.size() > 120:
        return
    var m := MeshInstance3D.new()
    var shape := SphereMesh.new()
    shape.radius = 0.11
    shape.height = 0.22
    m.mesh = shape
    m.material_override = _mat(tint,true)
    m.position = origin
    add_child(m)
    particles.append({"node":m,"velocity":Vector3(randf_range(-3,3),randf_range(1,5),randf_range(-3,3)),"time":lifetime})

func _update_particles(delta: float) -> void:
    for i in range(particles.size()-1,-1,-1):
        var p: Dictionary = particles[i]
        p.time -= delta
        if p.time <= 0:
            p.node.queue_free()
            particles.remove_at(i)
        else:
            p.node.position += p.velocity * delta
            particles[i] = p

func _dash() -> void:
    if not active:
        return
    hero.position += aim_direction * 5.0
    hero.position.x = clampf(hero.position.x,-148,148)
    hero.position.z = clampf(hero.position.z,-148,148)
    for i in range(16):
        _spark(hero.position + Vector3(0,0.8,0), COLORS[current_type],0.5)
