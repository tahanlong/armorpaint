package arm.nodes;

import iron.data.SceneFormat;
import iron.data.ShaderData;
import iron.data.MaterialData;
import arm.ui.UITrait;
import arm.ui.UINodes;
import arm.nodes.CyclesShader;
import arm.Tool;

class MaterialParser {

	static var sc:ShaderContext = null;
	static var _matcon:TMaterialContext = null;
	static var _materialcontext:MaterialContext = null;

	static function getMOut():Bool {
		for (n in UINodes.inst.canvas.nodes) if (n.type == "OUTPUT_MATERIAL_PBR") return true;
		return false;
	}

	public static function parseMeshMaterial() {
		if (UITrait.inst.worktab.position == SpaceScene) return;
		var m = Project.materials[0].data;
		// iron.data.Data.getMaterial("Scene", "Material", function(m:iron.data.MaterialData) {
			var sc:ShaderContext = null;
			for (c in m.shader.contexts) if (c.raw.name == "mesh") { sc = c; break; }
			if (sc != null) {
				m.shader.raw.contexts.remove(sc.raw);
				m.shader.contexts.remove(sc);
			}
			var con = MaterialBuilder.make_mesh(new CyclesShaderData({name: "Material", canvas: null}));
			if (sc != null) sc.delete();
			sc = new ShaderContext(con.data, function(sc:ShaderContext){});
			if (con.frag.sharedSamplers.length > 0) {
				sc.overrideContext = {}
				var sampler = con.frag.sharedSamplers[0];
				sc.overrideContext.shared_sampler = sampler.substr(sampler.lastIndexOf(" ") + 1);
			}
			m.shader.raw.contexts.push(sc.raw);
			m.shader.contexts.push(sc);
			Context.ddirty = 2;

			#if rp_voxelao
			if (MaterialBuilder.heightUsed && Config.raw.rp_gi != false) {
				var sc:ShaderContext = null;
				for (c in m.shader.contexts) if (c.raw.name == "voxel") { sc = c; break; }
				if (sc != null) MaterialBuilder.make_voxel(sc);
			}
			#end
		// });
	}

	public static function parseParticleMaterial() {
		var m = UITrait.inst.particleMaterial;
		// iron.data.Data.getMaterial("Scene", "MaterialParticle", function(m:iron.data.MaterialData) {
			var sc:ShaderContext = null;
			for (c in m.shader.contexts) if (c.raw.name == "mesh") { sc = c; break; }
			if (sc != null) {
				m.shader.raw.contexts.remove(sc.raw);
				m.shader.contexts.remove(sc);
			}
			var con = MaterialBuilder.make_particle(new CyclesShaderData({name: "MaterialParticle", canvas: null}));
			if (sc != null) sc.delete();
			sc = new ShaderContext(con.data, function(sc:ShaderContext){});
			m.shader.raw.contexts.push(sc.raw);
			m.shader.contexts.push(sc);
		// });
	}

	public static function parseMeshPreviewMaterial() {
		if (!getMOut()) return;

		var m = UITrait.inst.worktab.position == SpaceScene ? Context.materialScene.data : Project.materials[0].data;
		// iron.data.Data.getMaterial("Scene", "Material", function(m:iron.data.MaterialData) {

			var sc:ShaderContext = null;
			for (c in m.shader.contexts) if (c.raw.name == "mesh") { sc = c; break; }
			m.shader.raw.contexts.remove(sc.raw);
			m.shader.contexts.remove(sc);
			
			var matcon:TMaterialContext = { name: "mesh", bind_textures: [] };

			var sd = new CyclesShaderData({name: "Material", canvas: null});
			var con = MaterialBuilder.make_mesh_preview(sd, matcon);

			for (i in 0...m.contexts.length) {
				if (m.contexts[i].raw.name == "mesh") {
					m.contexts[i] = new MaterialContext(matcon, function(self:MaterialContext) {});
					break;
				}
			}
			
			if (sc != null) sc.delete();
			
			var compileError = false;
			sc = new ShaderContext(con.data, function(sc:ShaderContext) {
				if (sc == null) compileError = true;
			});
			if (compileError) return;

			m.shader.raw.contexts.push(sc.raw);
			m.shader.contexts.push(sc);

		// });
	}

	public static function parsePaintMaterial() {
		if (!getMOut()) return;
		
		if (UITrait.inst.worktab.position == SpaceScene) {
			parseMeshPreviewMaterial();
			return;
		}

		//
		var m = Project.materials[0].data;
		sc = null;
		_materialcontext = null;
		//
		// iron.data.Data.getMaterial("Scene", "Material", function(m:iron.data.MaterialData) {
		
			var mat:TMaterial = {
				name: "Material",
				canvas: UINodes.inst.canvas
			};
			var _sd = new CyclesShaderData(mat);

			if (sc == null) {
				for (c in m.shader.contexts) {
					if (c.raw.name == "paint") {
						sc = c;
						break;
					}
				}
			}
			if (_materialcontext == null) {
				for (c in m.contexts) {
					if (c.raw.name == "paint") {
						_materialcontext = c;
						_matcon = c.raw;
						break;
					}
				}
			}

			if (sc != null) {
				m.shader.raw.contexts.remove(sc.raw);
				m.shader.contexts.remove(sc);
			}
			if (_materialcontext != null) {
				m.raw.contexts.remove(_matcon);
				m.contexts.remove(_materialcontext);
			}

			_matcon = {
				name: "paint",
				bind_textures: []
			}

			var con = MaterialBuilder.make_paint(_sd, _matcon);
			var cdata = con.data;

				// from_source is synchronous..
				if (sc != null) sc.delete();
				
				var compileError = false;
				sc = new ShaderContext(cdata, function(sc:ShaderContext) {
					if (sc == null) compileError = true;
				});
				if (compileError) return;
				sc.overrideContext = {}
				sc.overrideContext.addressing = "repeat";
				
				m.shader.raw.contexts.push(sc.raw);
				m.shader.contexts.push(sc);
				m.raw.contexts.push(_matcon);

				new MaterialContext(_matcon, function(self:MaterialContext) {
					_materialcontext = self;
					m.contexts.push(self);
				});
		// });
	}

	public static function parseBrush() {
		Logic.packageName = "arm.nodes.brush";
		var tree = Logic.parse(UINodes.inst.canvasBrush, false);
	}
}
