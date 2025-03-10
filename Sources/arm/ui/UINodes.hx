package arm.ui;

import haxe.Json;
import kha.Blob;
import kha.Image;
import kha.System;
import zui.Zui;
import zui.Id;
import zui.Nodes;
import iron.data.Data;
import iron.system.Input;
import arm.nodes.NodesMaterial;
import arm.nodes.NodesBrush;
import arm.nodes.MaterialParser;
import arm.util.RenderUtil;
import arm.ui.UITrait;
import arm.data.BrushSlot;
import arm.data.MaterialSlot;
import arm.Tool;

@:access(zui.Zui)
class UINodes {

	public static var inst:UINodes;
	static var materialCounter = 0;

	public var show = false;
	public var wx:Int;
	public var wy:Int;
	public var ww:Int;
	public var wh:Int;

	public var ui:Zui;
	var drawMenu = false;
	var showMenu = false;
	var hideMenu = false;
	var menuCategory = 0;
	var addNodeButton = false;
	var popupX = 0.0;
	var popupY = 0.0;

	public var nodes:Nodes;
	public var canvas:TNodeCanvas = null;
	public var canvasMap:Map<MaterialSlot, TNodeCanvas> = null;
	public var canvasMap2:Map<MaterialSlot, TNodeCanvas> = null;
	var canvasBlob:String;

	public var canvasBrush:TNodeCanvas = null;
	public var canvasBrushMap:Map<BrushSlot, TNodeCanvas> = null;
	var canvasBrushBlob:String;

	public var canvasType = 0; // material, brush

	var mdown = false;
	var mreleased = false;
	var mchanged = false;
	var mstartedlast = false;
	public var changed = false;
	var recompileMat = false; // Mat preview
	var nodeSearchSpawn:TNode = null;
	var nodeSearchOffset = 0;
	var nodeSearchLast = "";

	public var grid:Image = null;
	public var hwnd = Id.handle();

	public function new() {
		inst = this;

		Nodes.excludeRemove.push("OUTPUT_MATERIAL_PBR");
		// Cycles.arm_export_tangents = false;

		Data.getBlob('defaults/default_material.json', function(b1:Blob) {
			Data.getBlob('defaults/default_brush.json', function(b2:Blob) {
				canvasBlob = b1.toString();
				canvasBrushBlob = b2.toString();
				canvas = Json.parse(canvasBlob);
				canvasBrush = Json.parse(canvasBrushBlob);
				MaterialParser.parseBrush();

				var t = Reflect.copy(App.theme);
				t.ELEMENT_H = 18;
				t.BUTTON_H = 16;
				var scale = Config.raw.window_scale;
				ui = new Zui({font: App.font, theme: t, color_wheel: App.color_wheel, scaleFactor: scale});
				ui.scrollEnabled = false;
			});
		});
	}

	public function updateCanvasMap() {
		if (UITrait.inst.worktab.position == SpaceScene) {
			if (canvasMap2 == null) canvasMap2 = new Map();
			var c = canvasMap2.get(Context.materialScene);
			if (c == null) {
				c = Json.parse(canvasBlob);
				canvasMap2.set(Context.materialScene, c);
				canvas = c;
			}
			else canvas = c;
			if (canvasType == 0) nodes = Context.materialScene.nodes;
			return;
		}

		if (Context.material != null) {
			if (canvasMap == null) canvasMap = new Map();
			var c = canvasMap.get(Context.material);
			if (c == null) {
				c = Json.parse(canvasBlob);
				canvasMap.set(Context.material, c);
				canvas = c;
				c.name = "Material " + (++materialCounter);
			}
			else canvas = c;

			if (canvasType == 0) nodes = Context.material.nodes;
		}
	}

	public function updateCanvasBrushMap() {
		if (Context.brush != null) {
			if (canvasBrushMap == null) canvasBrushMap = new Map();
			var c = canvasBrushMap.get(Context.brush);
			if (c == null) {
				c = Json.parse(canvasBrushBlob);
				canvasBrushMap.set(Context.brush, c);
				canvasBrush = c;
			}
			else canvasBrush = c;

			if (canvasType == 1) nodes = Context.brush.nodes;
		}
	}

	function getCanvas() {
		if (canvasType == 0) return canvas;
		else return canvasBrush;
	}

	function update() {
		updateCanvasMap();
		updateCanvasBrushMap();

		var mouse = Input.getMouse();
		mreleased = mouse.released();
		mdown = mouse.down();

		// Recompile material on change
		if (ui.changed) {
			mchanged = true;
			if (!mdown) changed = true;
			if (canvasType == 1) MaterialParser.parseBrush();
		}
		if ((mreleased && mchanged) || changed) {
			mchanged = changed = false;
			if (canvasType == 0) {
				if (Layers.isFillMaterial()) {
					Layers.updateFillLayers(); // TODO: jitter
					UITrait.inst.hwnd.redraws = 2;
				}
				MaterialParser.parsePaintMaterial();
				RenderUtil.makeMaterialPreview();
				UITrait.inst.hwnd1.redraws = 2;
				var decal = Context.tool == ToolDecal || Context.tool == ToolText;
				if (decal) RenderUtil.makeDecalPreview();
			}
		}
		else if (ui.changed && (mstartedlast || mouse.moved)) {
			recompileMat = true; // Instant preview
		}
		mstartedlast = mouse.started();

		if (!show) return;
		if (!App.uienabled) return;
		var kb = Input.getKeyboard();

		var lay = Config.raw.ui_layout;
		wx = lay == 0 ? Std.int(iron.App.w()) : UITrait.inst.windowW;
		wx += UITrait.inst.toolbarw;
		wy = UITrait.inst.headerh * 2;
		if (UIView2D.inst.show) {
			wy += Std.int(iron.App.h() / 2);
		}
		var ww = Std.int(iron.App.w()) + UITrait.inst.toolbarw;
		var mx = mouse.x + App.x();
		var my = mouse.y + App.y();
		if (mx < wx || mx > wx + ww || my < wy) return;
		if (ui.isTyping) return;

		if (addNodeButton) {
			showMenu = true;
			addNodeButton = false;
		}
		else if (mouse.released()) {
			hideMenu = true;
		}

		if (nodes.nodesSelected.length > 0) {
			if (kb.started("left")) for (n in nodes.nodesSelected) n.x -= 1;
			else if (kb.started("right")) for (n in nodes.nodesSelected) n.x += 1;
			if (kb.started("up")) for (n in nodes.nodesSelected) n.y -= 1;
			else if (kb.started("down")) for (n in nodes.nodesSelected) n.y += 1;
		}

		// Node search popup
		if (kb.started(Config.keymap.node_search)) nodeSearch();
		if (nodeSearchSpawn != null) {
			ui.inputX = mouse.x + App.x(); // Fix inputDX after popup removal
			ui.inputY = mouse.y + App.y();
			nodeSearchSpawn = null;
		}
	}

	function nodeSearch(x = -1, y = -1) {
		var kb = Input.getKeyboard();
		var searchHandle = Id.handle();
		var first = true;
		UIMenu.draw(function(ui:Zui) {
			ui.fill(0, 0, ui._w / ui.SCALE, ui.t.ELEMENT_H * 8, ui.t.WINDOW_BG_COL);
			ui.textInput(searchHandle, "");
			ui.changed = false;
			if (first) {
				first = false;
				ui.startTextEdit(searchHandle); // Focus search bar
				ui.textSelectedCurrentText = searchHandle.text;
				searchHandle.text = "";
				nodeSearchLast = "";
			}
			var search = ui.textSelectedCurrentText.toLowerCase();
			if (searchHandle.text != "") search = searchHandle.text;
			if (search != nodeSearchLast) {
				nodeSearchOffset = 0;
				nodeSearchLast = search;
			}
			if (ui.isKeyDown) { // Move selection
				if (ui.key == kha.input.KeyCode.Down && nodeSearchOffset < 6) nodeSearchOffset++;
				if (ui.key == kha.input.KeyCode.Up && nodeSearchOffset > 0) nodeSearchOffset--;
			}
			var enter = kb.down("enter");
			var count = 0;
			var BUTTON_COL = ui.t.BUTTON_COL;
			var nodeList = canvasType == 0 ? NodesMaterial.list : NodesBrush.list;
			for (list in nodeList) {
				for (n in list) {
					if (n.name.toLowerCase().indexOf(search) >= 0) {
						ui.t.BUTTON_COL = count == nodeSearchOffset ? ui.t.HIGHLIGHT_COL : ui.t.WINDOW_BG_COL;
						if (ui.button(n.name, Left) || (enter && count == nodeSearchOffset)) {
							var canvas = getCanvas();
							nodeSearchSpawn = makeNode(n, nodes, canvas); // Spawn selected node
							canvas.nodes.push(nodeSearchSpawn);
							nodes.nodesSelected = [nodeSearchSpawn];
							nodes.nodesDrag = true;
							hwnd.redraws = 2;
							if (enter) {
								ui.changed = true;
								count = 6; // Trigger break
							}
						}
						if (++count > 6) break;
					}
				}
				if (count > 6) break;
			}
			if (enter && count == 0) { // Hide popup on enter when node is not found
				ui.changed = true;
				searchHandle.text = "";
			}
			ui.t.BUTTON_COL = BUTTON_COL;
		}, x, y);
	}

	public function getNodeX():Int {
		var mouse = Input.getMouse();
		return Std.int((mouse.x + App.x() - wx - nodes.PAN_X()) / nodes.SCALE);
	}

	public function getNodeY():Int {
		var mouse = Input.getMouse();
		return Std.int((mouse.y + App.y() - wy - nodes.PAN_Y()) / nodes.SCALE);
	}

	public function drawGrid() {
		var ww = iron.App.w() + UITrait.inst.toolbarw;
		var wh = iron.App.h();
		var w = ww + 40 * 2;
		var h = wh + 40 * 2;
		if (w < 1) w = 1;
		if (h < 1) h = 1;
		grid = Image.createRenderTarget(w, h);
		grid.g2.begin(true, ui.t.SEPARATOR_COL);
		for (i in 0...Std.int(h / 40) + 1) {
			grid.g2.color = ui.t.WINDOW_BG_COL;
			grid.g2.drawLine(0, i * 40 + 20, w, i * 40 + 20);
		}
		for (i in 0...Std.int(w / 40) + 1) {
			grid.g2.color = ui.t.WINDOW_BG_COL;
			grid.g2.drawLine(i * 40 + 20, 0, i * 40 + 20, h);
		}
		grid.g2.end();
	}

	function render(g:kha.graphics2.Graphics) {
		if (recompileMat) {
			recompileMat = false;
			if (Layers.isFillMaterial()) {
				Layers.updateFillLayers();
			}
			else {
				RenderUtil.makeMaterialPreview();
			}
			UITrait.inst.hwnd1.redraws = 2;
		}

		if (!show) return;
		if (System.windowWidth() == 0 || System.windowHeight() == 0) return;
		
		if (!App.uienabled && ui.inputRegistered) ui.unregisterInput();
		if (App.uienabled && !ui.inputRegistered) ui.registerInput();
		
		g.end();

		if (grid == null) drawGrid();

		// Start with UI
		ui.begin(g);
		
		// Make window
		ww = Std.int(iron.App.w()) + UITrait.inst.toolbarw;
		var lay = Config.raw.ui_layout;
		wx = lay == 0 ? Std.int(iron.App.w()) : UITrait.inst.windowW;
		wx += UITrait.inst.toolbarw;
		wy = UITrait.inst.headerh * 2;
		var ew = Std.int(ui.ELEMENT_W() * 0.7);
		wh = iron.App.h();
		if (UIView2D.inst.show) {
			wh = Std.int(iron.App.h() / 2);
			wy += Std.int(iron.App.h() / 2);
		}
		if (ui.window(hwnd, wx, wy, ww, wh)) {
			
			// Grid
			ui.g.color = 0xffffffff;
			ui.g.drawImage(grid, (nodes.panX * nodes.SCALE) % 40 - 40, (nodes.panY * nodes.SCALE) % 40 - 40);

			// Nodes
			var c = getCanvas();
			nodes.nodeCanvas(ui, c);

			// Image node preview
			if (nodes.nodesSelected.length > 0 && nodes.nodesSelected[0].type == 'TEX_IMAGE') {
				var id = nodes.nodesSelected[0].buttons[0].default_value;
				if (id < Project.assets.length) {
					var img = UITrait.inst.getImage(Project.assets[id]);
					var tw = 64 * ui.SCALE;
					var th = tw * (img.height / img.width);
					ui.g.drawScaledImage(img, ww - tw - 20 * ui.SCALE, wh - th - 40 * ui.SCALE, tw, th);
				}
			}

			// Editable canvas name
			var ACCENT_COL = ui.t.ACCENT_COL;
			var BUTTON_H = ui.t.BUTTON_H;
			var ELEMENT_H = ui.t.ELEMENT_H;
			var FONT_SIZE = ui.fontSize;
			ui.t.ACCENT_COL = 0x00000000;
			ui.t.BUTTON_H = 30;
			ui.t.ELEMENT_H = 30;
			ui.fontSize = Std.int(22 * ui.SCALE);
			ui._x = ww - ui.ELEMENT_W() * 1.4;
			ui._y = wh - ui.ELEMENT_H() * 1.2;
			ui._w = Std.int(ui.ELEMENT_W() * 1.4);
			var h = Id.handle();
			h.text = c.name;
			c.name = ui.textInput(h, "", Right);
			ui.t.ACCENT_COL = ACCENT_COL;
			ui.t.BUTTON_H = BUTTON_H;
			ui.t.ELEMENT_H = ELEMENT_H;
			ui.fontSize = FONT_SIZE;

			// Menu
			ui.g.color = ui.t.WINDOW_BG_COL;
			ui.g.fillRect(0, 0, ww, 24 * ui.SCALE);
			ui.g.color = 0xffffffff;

			ui._x = 3;
			ui._y = 3;
			ui._w = ew;

			var BUTTON_COL = ui.t.BUTTON_COL;
			ui.t.BUTTON_COL = ui.t.WINDOW_BG_COL;

			var cats = canvasType == 0 ? NodesMaterial.categories : NodesBrush.categories;
			for (i in 0...cats.length) {
				if (ui.button(cats[i], Left) || (ui.isHovered && drawMenu)) {
					addNodeButton = true;
					menuCategory = i;
					popupX = wx + ui._x;
					popupY = wy + ui._y;
				}
				if (i < cats.length - 1) {
					ui._x += ew + 3;
					ui._y = 3;
				}
			}

			ui._x += ew + 3;
			ui._y = 3;
			if (ui.button("Search")) nodeSearch(Std.int(ui._windowX + ui._x), Std.int(ui._windowY + ui._y));
			if (ui.isHovered) ui.tooltip("(Space)");

			ui.t.BUTTON_COL = BUTTON_COL;
		}

		ui.endWindow();

		if (drawMenu) {
			var list = canvasType == 0 ? NodesMaterial.list : NodesBrush.list;
			var canvas = canvasType == 0 ? canvas : canvasBrush;
			var numNodes = list[menuCategory].length;
			
			var ph = numNodes * 20 * ui.SCALE;
			var py = popupY;
			g.color = ui.t.WINDOW_BG_COL;
			var menuw = Std.int(ew * 1.6);
			g.fillRect(popupX, py, menuw, ph);

			ui.beginLayout(g, Std.int(popupX), Std.int(py), menuw);
			var BUTTON_COL = ui.t.BUTTON_COL;
			ui.t.BUTTON_COL = ui.t.WINDOW_BG_COL;
			var ELEMENT_OFFSET = ui.t.ELEMENT_OFFSET;
			ui.t.ELEMENT_OFFSET = 0;
			var ELEMENT_H = ui.t.ELEMENT_H;
			ui.t.ELEMENT_H = 22;

			for (n in list[menuCategory]) {
				if (ui.button(n.name, Left)) {
					var node = makeNode(n, nodes, canvas);
					canvas.nodes.push(node);
					nodes.nodesSelected = [node];
					nodes.nodesDrag = true;
				}
			}

			ui.t.BUTTON_COL = BUTTON_COL;
			ui.t.ELEMENT_OFFSET = ELEMENT_OFFSET;
			ui.t.ELEMENT_H = ELEMENT_H;
			ui.endLayout();
		}

		ui.end();

		g.begin(false);

		if (showMenu) {
			showMenu = false;
			drawMenu = true;
			
		}
		if (hideMenu) {
			hideMenu = false;
			drawMenu = false;
		}
	}

	public function acceptDrag(assetIndex:Int) {
		var n = NodesMaterial.createImageTexture();
		n.buttons[0].default_value = assetIndex;
		nodes.nodesSelected = [n];
	}

	public static function makeNode(n:TNode, nodes:Nodes, canvas:TNodeCanvas):TNode {
		var node:TNode = Json.parse(Json.stringify(n));
		node.id = nodes.getNodeId(canvas.nodes);
		node.x = UINodes.inst.getNodeX();
		node.y = UINodes.inst.getNodeY();
		for (soc in node.inputs) {
			soc.id = nodes.getSocketId(canvas.nodes);
			soc.node_id = node.id;
		}
		for (soc in node.outputs) {
			soc.id = nodes.getSocketId(canvas.nodes);
			soc.node_id = node.id;
		}
		return node;
	}
}
