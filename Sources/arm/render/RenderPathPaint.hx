package arm.render;

import iron.object.MeshObject;
import iron.RenderPath;
import iron.Scene;
import arm.ui.UITrait;
import arm.Tool;

class RenderPathPaint {
	
	static var initVoxels = true; // Bake AO

	@:access(iron.RenderPath)
	public static function commandsPaint() {

		var path = RenderPathDeferred.path;
		var tid = Context.layer.id;
		
		if (Context.pdirty > 0 && UITrait.inst.worktab.position != SpaceScene) {
			if (Context.tool == ToolParticle) {
				path.setTarget("texparticle");
				path.clearTarget(0x00000000);
				path.bindTarget("_main", "gbufferD");
				if ((UITrait.inst.xray || UITrait.inst.brushAngleReject) && UITrait.inst.brush3d) path.bindTarget("gbuffer0", "gbuffer0");
				
				var mo:MeshObject = cast Scene.active.getChild(".ParticleEmitter");
				mo.visible = true;
				mo.render(path.currentG, "mesh", @:privateAccess path.bindParams);
				mo.visible = false;

				mo = cast Scene.active.getChild(".Particle");
				mo.visible = true;
				mo.render(path.currentG, "mesh", @:privateAccess path.bindParams);
				mo.visible = false;
				@:privateAccess path.end();
			}
			
			if (Context.tool == ToolColorId) {
				path.setTarget("texpaint_colorid");
				path.clearTarget(0xff000000);
				path.bindTarget("gbuffer2", "gbuffer2");
				path.drawMeshes("paint");
				UITrait.inst.headerHandle.redraws = 2;
			}
			else if (Context.tool == ToolPicker) {
				path.setTarget("texpaint_picker", ["texpaint_nor_picker", "texpaint_pack_picker"]);
				path.clearTarget(0xff000000);
				path.bindTarget("gbuffer2", "gbuffer2");
				tid = Project.layers[0].id;
				path.bindTarget("texpaint" + tid, "texpaint");
				path.bindTarget("texpaint_nor" + tid, "texpaint_nor");
				path.bindTarget("texpaint_pack" + tid, "texpaint_pack");
				path.drawMeshes("paint");
				UITrait.inst.headerHandle.redraws = 2;

				var texpaint_picker = path.renderTargets.get("texpaint_picker").image;
				var texpaint_nor_picker = path.renderTargets.get("texpaint_nor_picker").image;
				var texpaint_pack_picker = path.renderTargets.get("texpaint_pack_picker").image;
				var a = texpaint_picker.getPixels();
				var b = texpaint_nor_picker.getPixels();
				var c = texpaint_pack_picker.getPixels();
				// Picked surface values
				UITrait.inst.baseRPicked = a.get(0) / 255;
				UITrait.inst.baseGPicked = a.get(1) / 255;
				UITrait.inst.baseBPicked = a.get(2) / 255;
				UITrait.inst.normalRPicked = b.get(0) / 255;
				UITrait.inst.normalGPicked = b.get(1) / 255;
				UITrait.inst.normalBPicked = b.get(2) / 255;
				UITrait.inst.occlusionPicked = c.get(0) / 255;
				UITrait.inst.roughnessPicked = c.get(1) / 255;
				UITrait.inst.metallicPicked = c.get(2) / 255;
				// Pick material
				if (UITrait.inst.pickerSelectMaterial) {
					var matid = b.get(3);
					for (m in Project.materials) {
						if (m.id == matid) {
							Context.setMaterial(m);
							UITrait.inst.materialIdPicked = matid;
							break;
						}
					}
				}
			}
			else {
				if (Context.tool == ToolBake && UITrait.inst.bakeType == 0) { // AO
					if (initVoxels) {
						initVoxels = false;
						// Init voxel texture
						var rp_gi = Config.raw.rp_gi;
						Config.raw.rp_gi = true;
						#if rp_voxelao
						Inc.initGI();
						#end
						Config.raw.rp_gi = rp_gi;
					}
					path.clearImage("voxels", 0x00000000);
					path.setTarget("");
					path.setViewport(256, 256);
					path.bindTarget("voxels", "voxels");
					path.drawMeshes("voxel");
					path.generateMipmaps("voxels");
				}

				var blendA = "texpaint_blend0";
				var blendB = "texpaint_blend1";
				path.setTarget(blendB);
				path.bindTarget(blendA, "tex");
				path.drawShader("shader_datas/copy_pass/copy_pass");
				var isMask = Context.layerIsMask;
				var texpaint = isMask ? "texpaint_mask" + tid : "texpaint" + tid;
				path.setTarget(texpaint, ["texpaint_nor" + tid, "texpaint_pack" + tid, blendA]);
				path.bindTarget("_main", "gbufferD");
				if ((UITrait.inst.xray || UITrait.inst.brushAngleReject) && UITrait.inst.brush3d) {
					path.bindTarget("gbuffer0", "gbuffer0");
				}
				path.bindTarget(blendB, "paintmask");
				if (Context.tool == ToolBake && UITrait.inst.bakeType == 0) { // AO
					path.bindTarget("voxels", "voxels");
				}
				if (UITrait.inst.colorIdPicked) {
					path.bindTarget("texpaint_colorid", "texpaint_colorid");
				} 

				// Read texcoords from gbuffer
				var readTC = (Context.tool == ToolFill && UITrait.inst.fillTypeHandle.position == 1) || // Face fill
							  Context.tool == ToolClone ||
							  Context.tool == ToolBlur;
				if (readTC) {
					path.bindTarget("gbuffer2", "gbuffer2");
				}

				path.drawMeshes("paint");

				if (Context.tool == ToolBake && UITrait.inst.bakeType == 1 && UITrait.inst.bakeCurvSmooth > 0) { // Curvature
					if (path.renderTargets.get("texpaint_blur") == null) {
						var t = new RenderTargetRaw();
						t.name = "texpaint_blur";
						t.width = Std.int(Config.getTextureRes() * 0.95);
						t.height = Std.int(Config.getTextureRes() * 0.95);
						t.format = 'RGBA32';
						RenderPath.active.createRenderTarget(t);
					}
					var blurs = Math.round(UITrait.inst.bakeCurvSmooth);
					for (i in 0...blurs) {
						path.setTarget("texpaint_blur");
						path.bindTarget(texpaint, "tex");
						path.drawShader("shader_datas/copy_pass/copy_pass");
						path.setTarget(texpaint);
						path.bindTarget("texpaint_blur", "tex");
						path.drawShader("shader_datas/copy_pass/copy_pass");
					}
				}
			}
		}
	}

	@:access(iron.RenderPath)
	public static function commandsCursor() {
		var tool = Context.tool;
		if (tool != ToolBrush &&
			tool != ToolEraser &&
			tool != ToolClone &&
			tool != ToolBlur &&
			tool != ToolParticle) {
			// tool != ToolDecal &&
			// tool != ToolText) {
				return;
		}
		if (!App.uienabled ||
			UITrait.inst.worktab.position == SpaceScene) {
			return;
		}

		var path = RenderPathDeferred.path;

		var plane = cast(Scene.active.getChild(".Plane"), MeshObject);
		var geom = plane.data.geom;

		var g = path.frameG;
		if (Layers.pipeCursor == null) Layers.makeCursorPipe();

		path.setTarget("");
		g.setPipeline(Layers.pipeCursor);
		var decal = Context.tool == ToolDecal || Context.tool == ToolText;
		var img = decal ? UITrait.inst.decalImage : Res.get("cursor.png");
		g.setTexture(Layers.cursorTex, img);
		var gbuffer0 = path.renderTargets.get("gbuffer0").image;
		g.setTextureDepth(Layers.cursorGbufferD, gbuffer0);
		g.setTexture(Layers.cursorGbuffer0, gbuffer0);
		var mx = iron.system.Input.getMouse().x / iron.App.w();
		var my = 1.0 - (iron.system.Input.getMouse().y / iron.App.h());
		if (UITrait.inst.brushLocked) {
			mx = (UITrait.inst.lockStartedX - iron.App.x()) / iron.App.w();
			my = 1.0 - (UITrait.inst.lockStartedY - iron.App.y()) / iron.App.h();
		}
		g.setFloat2(Layers.cursorMouse, mx, my);
		g.setFloat2(Layers.cursorStep, 2 / gbuffer0.width, 2 / gbuffer0.height);
		g.setFloat(Layers.cursorRadius, UITrait.inst.brushRadius / 3.4);
		g.setMatrix(Layers.cursorVP, Scene.active.camera.VP.self);
		var helpMat = iron.math.Mat4.identity();
		helpMat.getInverse(Scene.active.camera.VP);
		g.setMatrix(Layers.cursorInvVP, helpMat.self);
		g.setVertexBuffer(geom.vertexBuffer);
		g.setIndexBuffer(geom.indexBuffers[0]);
		g.drawIndexedVertices();
		
		g.disableScissor();
		path.end();
	}
}
