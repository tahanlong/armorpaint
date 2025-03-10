package arm.ui;

import zui.Id;
import iron.data.Data;
import arm.nodes.MaterialParser;
import arm.data.LayerSlot;

class TabPreferences {

	@:access(zui.Zui)
	public static function draw() {
		var ui = UITrait.inst.ui;
		if (ui.tab(UITrait.inst.htab, "Preferences")) {
			if (ui.panel(Id.handle({selected: false}), "Interface", 1)) {
				var hscale = Id.handle({value: Config.raw.window_scale});
				ui.slider(hscale, "UI Scale", 0.5, 4.0, true);
				if (!hscale.changed && UITrait.inst.hscaleWasChanged) {
					#if kha_krom
					if (hscale.value == null || Math.isNaN(hscale.value)) hscale.value = 1.0;
					#end
					Config.raw.window_scale = hscale.value;
					ui.setScale(hscale.value);
					App.uibox.setScale(hscale.value);
					UINodes.inst.ui.setScale(hscale.value);
					UIView2D.inst.ui.setScale(hscale.value);
					UITrait.inst.windowW = Std.int(UITrait.defaultWindowW * Config.raw.window_scale);
					UITrait.inst.toolbarw = Std.int(UITrait.defaultToolbarW * Config.raw.window_scale);
					UITrait.inst.headerh = Std.int(UITrait.defaultHeaderH * Config.raw.window_scale);
					UITrait.inst.menubarw = Std.int(215 * Config.raw.window_scale);
					App.resize();
					Config.save();
					UITrait.inst.setIconScale();
				}
				UITrait.inst.hscaleWasChanged = hscale.changed;
				ui.row([1/2, 1/2]);
				var layHandle = Id.handle({position: Config.raw.ui_layout});
				Config.raw.ui_layout = ui.combo(layHandle, ["Right", "Left"], "Layout", true);
				if (layHandle.changed) {
					App.resize();
					Config.save();
				}
				var themeHandle = Id.handle({position: 0});
				var themes = ["Dark", "Light"];
				ui.combo(themeHandle, themes, "Theme", true);
				if (themeHandle.changed) {
					var theme = themes[themeHandle.position].toLowerCase();
					if (theme == "dark") { // Built-in default
						App.theme = zui.Themes.dark;
					}
					else {
						Data.getBlob("themes/theme_" + theme + ".arm", function(b:kha.Blob) {
							App.theme = haxe.Json.parse(b.toString());
						});
					}
					ui.t = App.theme;
					// UINodes.inst.applyTheme();
					UITrait.inst.headerHandle.redraws = 2;
					UITrait.inst.toolbarHandle.redraws = 2;
					UITrait.inst.statusHandle.redraws = 2;
					UITrait.inst.workspaceHandle.redraws = 2;
					UITrait.inst.menuHandle.redraws = 2;
					UITrait.inst.hwnd.redraws = 2;
					UITrait.inst.hwnd1.redraws = 2;
					UITrait.inst.hwnd2.redraws = 2;
				}
				// var gridSnap = ui.check(Id.handle({selected: false}), "Node Grid Snap");
			}

			ui.separator();
			if (ui.panel(Id.handle({selected: false}), "Usage", 1)) {
				UITrait.inst.undoHandle = Id.handle({value: Config.raw.undo_steps});
				Config.raw.undo_steps = Std.int(ui.slider(UITrait.inst.undoHandle, "Undo Steps", 2, 64, false, 1));
				if (UITrait.inst.undoHandle.changed) {
					ui.g.end();
					while (History.undoLayers.length < Config.raw.undo_steps) {
						var l = new LayerSlot("_undo" + History.undoLayers.length);
						l.createMask(0, false);
						History.undoLayers.push(l);
					}
					while (History.undoLayers.length > Config.raw.undo_steps) {
						var l = History.undoLayers.pop();
						l.unload();
					}
					History.reset();
					ui.g.begin(false);
					Config.save();
				}

				UITrait.inst.brushBias = ui.slider(Id.handle({value: UITrait.inst.brushBias}), "Paint Bias", 0.0, 1.0, true);

				var brush3dHandle = Id.handle({selected: UITrait.inst.brush3d});
				UITrait.inst.brush3d = ui.check(brush3dHandle, "3D Cursor");
				if (brush3dHandle.changed) MaterialParser.parsePaintMaterial();

				ui.enabled = UITrait.inst.brush3d;
				var brushDepthRejectHandle = Id.handle({selected: UITrait.inst.brushDepthReject});
				UITrait.inst.brushDepthReject = ui.check(brushDepthRejectHandle, "Depth Reject");
				if (brushDepthRejectHandle.changed) MaterialParser.parsePaintMaterial();

				ui.row([1/2,1/2]);

				var brushAngleRejectHandle = Id.handle({selected: UITrait.inst.brushAngleReject});
				UITrait.inst.brushAngleReject = ui.check(brushAngleRejectHandle, "Angle Reject");
				if (brushAngleRejectHandle.changed) MaterialParser.parsePaintMaterial();

				if (!UITrait.inst.brushAngleReject) ui.enabled = false;
				var angleDotHandle = Id.handle({value: UITrait.inst.brushAngleRejectDot});
				UITrait.inst.brushAngleRejectDot = ui.slider(angleDotHandle, "Angle", 0.0, 1.0, true);
				if (angleDotHandle.changed) {
					MaterialParser.parsePaintMaterial();
				}
				ui.enabled = true;
			}

			ui.separator();
			if (ui.panel(Id.handle({selected: false}), "Pen Pressure", 1)) {
				UITrait.penPressureRadius = ui.check(Id.handle({selected: UITrait.penPressureRadius}), "Brush Radius");
				UITrait.penPressureOpacity = ui.check(Id.handle({selected: UITrait.penPressureOpacity}), "Brush Opacity");
				UITrait.penPressureHardness = ui.check(Id.handle({selected: UITrait.penPressureHardness}), "Brush Hardness");
			}

			UITrait.inst.hssgi = Id.handle({selected: Config.raw.rp_ssgi});
			UITrait.inst.hssr = Id.handle({selected: Config.raw.rp_ssr});
			UITrait.inst.hbloom = Id.handle({selected: Config.raw.rp_bloom});
			UITrait.inst.hsupersample = Id.handle({position: Config.getSuperSampleQuality(Config.raw.rp_supersample)});
			UITrait.inst.hvxao = Id.handle({selected: Config.raw.rp_gi});
			ui.separator();
			if (ui.panel(Id.handle({selected: false}), "Viewport Quality", 1)) {
				ui.row([1/2, 1/2]);
				var vsyncHandle = Id.handle({selected: Config.raw.window_vsync});
				Config.raw.window_vsync = ui.check(vsyncHandle, "VSync");
				if (vsyncHandle.changed) Config.save();
				ui.combo(UITrait.inst.hsupersample, ["1.0x", "1.5x", "2.0x", "4.0x"], "Super Sample", true);
				if (UITrait.inst.hsupersample.changed) Config.applyConfig();
				ui.row([1/2, 1/2]);
				ui.check(UITrait.inst.hvxao, "Voxel AO");
				if (ui.isHovered) ui.tooltip("Cone-traced AO and shadows");
				if (UITrait.inst.hvxao.changed) Config.applyConfig();
				ui.check(UITrait.inst.hssgi, "SSAO");
				if (UITrait.inst.hssgi.changed) Config.applyConfig();
				ui.row([1/2, 1/2]);
				ui.check(UITrait.inst.hbloom, "Bloom");
				if (UITrait.inst.hbloom.changed) Config.applyConfig();
				ui.check(UITrait.inst.hssr, "SSR");
				if (UITrait.inst.hssr.changed) Config.applyConfig();
				var cullHandle = Id.handle({selected: UITrait.inst.culling});
				UITrait.inst.culling = ui.check(cullHandle, "Cull Backfaces");
				if (cullHandle.changed) {
					MaterialParser.parseMeshMaterial();
				}
			}

			ui.separator();
			if (ui.panel(Id.handle({selected: false}), "Keymap", 1)) {

				var presetHandle = Id.handle();
				ui.combo(presetHandle, ["Default", "Blender"], "Preset", true);
				if (presetHandle.changed) {
					var preset = presetHandle.position;
					var keymap = Config.keymap;
					if (preset == 0) {
						keymap.action_rotate = "alt+left";
						keymap.action_pan = "alt+middle";
						keymap.action_zoom = "alt+right";
					}
					else if (preset == 1) {
						keymap.action_rotate = "middle";
						keymap.action_pan = "shift+middle";
						keymap.action_zoom = "ctrl+middle";
					}
					Config.applyConfig();
				}
				ui.separator(8, false);

				var i = 0;
				ui.changed = false;
				for (key in Reflect.fields(Config.keymap)) {
					var h = Id.handle().nest(i++);
					h.text = Reflect.field(Config.keymap, key);
					var text = ui.textInput(h, key, Left);
					Reflect.setField(Config.keymap, key, text);
				}
				if (ui.changed) Config.applyConfig();
			}

			// if (ui.button("Restore Defaults")) {
			// 	Config.raw = Config.init();
			// 	Config.keymap = Config.raw.keymap;
			// 	Config.applyConfig();
			// }
		}
	}
}
