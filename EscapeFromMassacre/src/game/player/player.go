components {
  id: "script"
  component: "/src/game/player/player.script"
}
components {
  id: "level_up"
  component: "/assets/explode.particlefx"
}
embedded_components {
  id: "collisionobject"
  type: "collisionobject"
  data: "type: COLLISION_OBJECT_TYPE_KINEMATIC\n"
  "mass: 0.0\n"
  "friction: 0.1\n"
  "restitution: 0.5\n"
  "group: \"player\"\n"
  "mask: \"wall\"\n"
  "mask: \"wall_basement\"\n"
  "mask: \"bullet\"\n"
  "mask: \"zombie\"\n"
  "mask: \"detection\"\n"
  "mask: \"stairs_to_basement\"\n"
  "mask: \"stairs_to_house\"\n"
  "mask: \"knife\"\n"
  "mask: \"fuze\"\n"
  "mask: \"box\"\n"
  "mask: \"fuze-box\"\n"
  "mask: \"exit\"\n"
  "embedded_collision_shape {\n"
  "  shapes {\n"
  "    shape_type: TYPE_SPHERE\n"
  "    position {\n"
  "    }\n"
  "    rotation {\n"
  "    }\n"
  "    index: 0\n"
  "    count: 1\n"
  "  }\n"
  "  data: 20.0\n"
  "}\n"
  ""
}
embedded_components {
  id: "sprite"
  type: "sprite"
  data: "default_animation: \"hitman1_machine\"\n"
  "material: \"/builtins/materials/sprite.material\"\n"
  "textures {\n"
  "  sampler: \"texture_sampler\"\n"
  "  texture: \"/assets/rotate_and_move.atlas\"\n"
  "}\n"
  ""
  position {
    y: 10.0
  }
}
embedded_components {
  id: "name"
  type: "label"
  data: "size {\n"
  "  x: 138.0\n"
  "  y: 32.0\n"
  "}\n"
  "outline {\n"
  "  x: 1.0\n"
  "  y: 1.0\n"
  "  z: 1.0\n"
  "}\n"
  "shadow {\n"
  "  x: 1.0\n"
  "  y: 1.0\n"
  "  z: 1.0\n"
  "}\n"
  "line_break: true\n"
  "text: \"user-32!kjhas nqwe qweokk adsa\"\n"
  "font: \"/builtins/fonts/default.font\"\n"
  "material: \"/builtins/fonts/label.material\"\n"
  ""
  position {
    y: -44.0
  }
}
embedded_components {
  id: "scale"
  type: "sprite"
  data: "default_animation: \"scale\"\n"
  "material: \"/builtins/materials/sprite.material\"\n"
  "textures {\n"
  "  sampler: \"texture_sampler\"\n"
  "  texture: \"/assets/rotate_and_move.atlas\"\n"
  "}\n"
  ""
  position {
    y: -20.0
    z: 0.2
  }
  scale {
    x: 0.2
    y: 0.2
  }
}
embedded_components {
  id: "scale-fill"
  type: "sprite"
  data: "default_animation: \"scale-fill\"\n"
  "material: \"/builtins/materials/sprite.material\"\n"
  "textures {\n"
  "  sampler: \"texture_sampler\"\n"
  "  texture: \"/assets/rotate_and_move.atlas\"\n"
  "}\n"
  ""
  position {
    y: -20.0
  }
  scale {
    x: 0.2
    y: 0.2
  }
}
embedded_components {
  id: "scale-health"
  type: "sprite"
  data: "default_animation: \"scale-health\"\n"
  "material: \"/builtins/materials/sprite.material\"\n"
  "size {\n"
  "  x: 318.0\n"
  "  y: 40.0\n"
  "}\n"
  "size_mode: SIZE_MODE_MANUAL\n"
  "textures {\n"
  "  sampler: \"texture_sampler\"\n"
  "  texture: \"/assets/rotate_and_move.atlas\"\n"
  "}\n"
  ""
  position {
    x: 6.0
    y: -18.0
    z: 0.1
  }
  scale {
    x: 0.2
    y: 0.2
  }
}
embedded_components {
  id: "scale-manna"
  type: "sprite"
  data: "default_animation: \"scale-manna\"\n"
  "material: \"/builtins/materials/sprite.material\"\n"
  "textures {\n"
  "  sampler: \"texture_sampler\"\n"
  "  texture: \"/assets/rotate_and_move.atlas\"\n"
  "}\n"
  ""
  position {
    x: 6.0
    y: -24.0
    z: 0.1
  }
  scale {
    x: 0.2
    y: 0.2
  }
}
embedded_components {
  id: "scale-level"
  type: "label"
  data: "size {\n"
  "  x: 128.0\n"
  "  y: 32.0\n"
  "}\n"
  "outline {\n"
  "  x: 1.0\n"
  "  y: 1.0\n"
  "  z: 1.0\n"
  "}\n"
  "shadow {\n"
  "  x: 1.0\n"
  "  y: 1.0\n"
  "  z: 1.0\n"
  "}\n"
  "line_break: true\n"
  "text: \"1\"\n"
  "font: \"/builtins/fonts/default.font\"\n"
  "material: \"/builtins/fonts/label.material\"\n"
  ""
  position {
    x: -32.0
    y: -20.0
    z: 0.2
  }
  scale {
    x: 0.5
    y: 0.5
  }
}
embedded_components {
  id: "sprite-fuze-1"
  type: "sprite"
  data: "default_animation: \"fuze_red\"\n"
  "material: \"/builtins/materials/sprite.material\"\n"
  "textures {\n"
  "  sampler: \"texture_sampler\"\n"
  "  texture: \"/assets/rotate_and_move.atlas\"\n"
  "}\n"
  ""
  position {
    x: 30.0
  }
  scale {
    x: 0.4
    y: 0.4
  }
}
embedded_components {
  id: "sprite-fuze-2"
  type: "sprite"
  data: "default_animation: \"fuze_green\"\n"
  "material: \"/builtins/materials/sprite.material\"\n"
  "textures {\n"
  "  sampler: \"texture_sampler\"\n"
  "  texture: \"/assets/rotate_and_move.atlas\"\n"
  "}\n"
  ""
  position {
    x: 30.0
    y: 10.0
  }
  scale {
    x: 0.4
    y: 0.4
  }
}
embedded_components {
  id: "sprite-fuze-3"
  type: "sprite"
  data: "default_animation: \"fuze_blue\"\n"
  "material: \"/builtins/materials/sprite.material\"\n"
  "textures {\n"
  "  sampler: \"texture_sampler\"\n"
  "  texture: \"/assets/rotate_and_move.atlas\"\n"
  "}\n"
  ""
  position {
    x: 40.0
  }
  scale {
    x: 0.4
    y: 0.4
  }
}
embedded_components {
  id: "sprite-fuze-4"
  type: "sprite"
  data: "default_animation: \"fuze_yellow\"\n"
  "material: \"/builtins/materials/sprite.material\"\n"
  "textures {\n"
  "  sampler: \"texture_sampler\"\n"
  "  texture: \"/assets/rotate_and_move.atlas\"\n"
  "}\n"
  ""
  position {
    x: 40.0
    y: 10.0
  }
  scale {
    x: 0.4
    y: 0.4
  }
}
