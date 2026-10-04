"""
octo_studio_app.py - Aplicación Gráfica de Escritorio interactiva en Python
para el sistema de Avatares OCTOPLAYER (8 Direcciones).
Integra:
- Pose Detenida (Idle): female1.png .. female8.png
- Animación de Caminata (Walk): female1_walk_f1.png .. female8_walk_f4.png
- Creación de Ropa y Peinados con PixelLab API.
"""

import os
import sys
import json
import glob
import threading
import tkinter as tk
from tkinter import ttk, colorchooser, messagebox, filedialog
from PIL import Image, ImageTk, ImageDraw

import octo_engine
from octo_engine import (
    DIRECTIONS,
    get_octo_catalog,
    get_default_config,
    compose_octo_avatar,
    clear_cache,
    OCTO_AVATAR_DIR
)
import furniture_inspector_engine as fie
import bed_sleep_calibrator as bsc
from color_engine import RETRO_PALETTES, hex_to_rgb, rgb_to_hex
import pixellab_service
from pixellab_service import PixelLabClient, load_pixellab_key, save_pixellab_key

PRESETS_DIR = "presets_octo"
EXPORTS_DIR = "exports_octo"
os.makedirs(PRESETS_DIR, exist_ok=True)
os.makedirs(EXPORTS_DIR, exist_ok=True)

class OctoStudioApp:
    def __init__(self, root):
        self.root = root
        self.root.title("OctoStudio 8D — Avatar Studio & Inspector de Muebles")
        self.root.geometry("1260x860")
        self.root.minsize(1120, 740)
        self.root.configure(bg="#12131C")

        # Estado del avatar
        self.config = get_default_config()
        self.current_direction = 1 # 1..8
        self.current_action = "walk" # "idle", "walk", o "sit"
        self.current_frame = 0 # 0..3 (walk) o 0..2 (sit)
        self.is_playing = True # Reproduciendo animación
        self.is_auto_rotating = False
        self.fps = 6
        self.zoom_level = 3
        self.anim_loop_id = None

        # Desplazamiento (pan) del avatar en el visor con mouse
        self.avatar_pan_x = 0
        self.avatar_pan_y = 0
        self.is_dragging_avatar = False
        self.drag_start_x = 0
        self.drag_start_y = 0

        # Estado de minimización del panel de personaje
        self.is_left_panel_minimized = False
        self.left_panel_saved_width = 440

        # Catálogo de assets avatar
        self.catalog = get_octo_catalog()

        # Estado de muebles (EXCLUSIVO de furniture/new_added)
        self.furn_catalog = fie.scan_new_added_furniture()
        self.furn_filter_var = tk.StringVar(value="all")
        default_furn = "simple_chair" if "simple_chair" in self.furn_catalog else (list(self.furn_catalog.keys())[0] if self.furn_catalog else "")
        self.selected_furn_id = tk.StringVar(value=default_furn)
        self.selected_furn_rot = 0
        self.custom_sprite_offset = None
        self.show_tiles_var = tk.BooleanVar(value=True)
        self.show_subcells_var = tk.BooleanVar(value=True)
        self.show_origin_var = tk.BooleanVar(value=True)
        self.show_bbox_var = tk.BooleanVar(value=False)
        self.show_avatar_on_furn_var = tk.BooleanVar(value=True)
        self.furn_zoom = 2
        self.furn_preview_tk = None

        # Estado calibrador de asientos (SeatSpot)
        self.seat_slot_idx = 0
        self.seat_sub_u = tk.IntVar(value=0)
        self.seat_sub_v = tk.IntVar(value=0)
        self.seat_voff_x = tk.DoubleVar(value=-2.0)
        self.seat_voff_y = tk.DoubleVar(value=0.0)
        self.seat_toff_x = tk.DoubleVar(value=0.0)
        self.seat_toff_y = tk.DoubleVar(value=-18.0)

        # Estado calibrador de camas (acostarse) — fuente de verdad: bed_sleep_config.dart
        self.show_lying_var = tk.BooleanVar(value=False)
        self.lie_under_var = tk.BooleanVar(value=False)
        self.lie_body_var = tk.StringVar(value="male")
        self.lie_hair_var = tk.StringVar(value="comb_over")
        self.lie_eyes_var = tk.StringVar(value="cateyes")
        self.lie_mouth_var = tk.StringVar(value="smile")
        self.lie_nose_var = tk.StringVar(value="standard")
        self.lie_top_var = tk.StringVar(value="jacket")
        self.lie_bottom_var = tk.StringVar(value="jeans")
        self.lie_acc_var = tk.StringVar(value="none")
        self.lie_wardrobe_colors_var = tk.BooleanVar(value=True)
        self.lie_sync_mirror_var = tk.BooleanVar(value=True)
        self.lie_step_var = tk.IntVar(value=1)
        try:
            self.bed_spots = bsc.load_spots()
        except Exception as e:  # el archivo Dart no está: el calibrador queda deshabilitado
            print("No se pudo leer bed_sleep_config.dart:", e)
            self.bed_spots = {}

        # Estado calibrador de superficies (Múltiples Lugares / Spots)
        self.surface_support_id = tk.StringVar(value="table")
        self.surface_height_var = tk.IntVar(value=22)
        self.surface_off_x = tk.IntVar(value=0)
        self.surface_off_y = tk.IntVar(value=0)
        self.surface_spot_idx = 0
        self.surface_sub_u = tk.IntVar(value=0)
        self.surface_sub_v = tk.IntVar(value=0)
        self.surface_spot_item = tk.StringVar(value="table_lamp")
        self.show_all_surf_items_var = tk.BooleanVar(value=True)
        self.show_surf_markers_var = tk.BooleanVar(value=True)
        self.current_surface_spots = []


        # Cliente de PixelLab
        self.pixellab_client = PixelLabClient()
        self.pending_ai_layer = None

        self._init_styles()
        self._build_ui()
        self.update_avatar_preview()
        self._start_animation_loop()

        # Atajos de teclado
        self.root.bind("<Left>", lambda e: self._rotate_step(-1))
        self.root.bind("<Right>", lambda e: self._rotate_step(1))
        self.root.bind("<space>", lambda e: self._toggle_play())
        self.root.bind("<Shift-Left>", lambda e: self._nudge_avatar_pan(-10, 0))
        self.root.bind("<Shift-Right>", lambda e: self._nudge_avatar_pan(10, 0))
        self.root.bind("<Shift-Up>", lambda e: self._nudge_avatar_pan(0, -10))
        self.root.bind("<Shift-Down>", lambda e: self._nudge_avatar_pan(0, 10))
        self.root.bind("<Home>", lambda e: self._reset_avatar_pan())

    def _init_styles(self):
        self.style = ttk.Style()
        self.style.theme_use("clam")

        self.style.configure(".", background="#181926", foreground="#E2E8F0", font=("Segoe UI", 9))
        self.style.configure("TNotebook", background="#12131C", borderwidth=0)
        self.style.configure("TNotebook.Tab", background="#222436", foreground="#94A3B8", padding=[14, 8], font=("Segoe UI", 9, "bold"))
        self.style.map("TNotebook.Tab", background=[("selected", "#2563EB")], foreground=[("selected", "#FFFFFF")])

        self.style.configure("TFrame", background="#181926")
        self.style.configure("TLabelframe", background="#181926", foreground="#38BDF8")
        self.style.configure("TLabelframe.Label", background="#181926", foreground="#38BDF8", font=("Segoe UI", 9, "bold"))
        self.style.configure("TLabel", background="#181926", foreground="#F1F5F9")
        self.style.configure("TCombobox", fieldbackground="#12131C", background="#2D3250", foreground="#FFFFFF", arrowcolor="#38BDF8")
        self.style.map("TCombobox", fieldbackground=[("readonly", "#12131C")], foreground=[("readonly", "#FFFFFF")])

    def _build_ui(self):
        self.main_paned = tk.PanedWindow(self.root, orient=tk.HORIZONTAL, bg="#12131C", bd=0, sashwidth=4)
        self.main_paned.pack(fill=tk.BOTH, expand=True, padx=10, pady=10)

        # =====================================================================
        # PANEL IZQUIERDO: VISOR 8D, BRÚJULA Y ANIMACIÓN
        # =====================================================================
        self.left_frame = tk.Frame(self.main_paned, bg="#181926", width=440)
        self.main_paned.add(self.left_frame, minsize=410)

        # Barra lateral minimizada (para restaurar el panel)
        self.minimized_left_bar = tk.Frame(self.main_paned, bg="#181926", width=46)
        exp_btn = tk.Button(
            self.minimized_left_bar,
            text="▶",
            font=("Segoe UI", 12, "bold"),
            bg="#2563EB",
            fg="#FFFFFF",
            activebackground="#3B82F6",
            activeforeground="#FFFFFF",
            bd=0,
            padx=4,
            pady=10,
            cursor="hand2",
            command=self._toggle_minimize_left_panel
        )
        exp_btn.pack(side=tk.TOP, fill=tk.X, padx=4, pady=(8, 4))

        vert_lbl = tk.Label(
            self.minimized_left_bar,
            text="P\nE\nR\nS\nO\nN\nA\nJ\nE",
            font=("Segoe UI", 8, "bold"),
            bg="#181926",
            fg="#38BDF8",
            cursor="hand2"
        )
        vert_lbl.pack(side=tk.TOP, pady=8)
        vert_lbl.bind("<Button-1>", lambda e: self._toggle_minimize_left_panel())

        # Cabecera del Panel Izquierdo
        hdr = tk.Frame(self.left_frame, bg="#181926")
        hdr.pack(fill=tk.X, padx=12, pady=(8, 4))
        tk.Label(hdr, text="🧭 Visor 8D (OCTOPLAYER)", font=("Segoe UI", 11, "bold"), bg="#181926", fg="#38BDF8").pack(side=tk.LEFT)

        # Botón Minimizar Panel
        self.min_btn = tk.Button(
            hdr,
            text="◀ Minimizar",
            font=("Segoe UI", 8, "bold"),
            bg="#1E293B",
            fg="#94A3B8",
            activebackground="#334155",
            activeforeground="#FFFFFF",
            bd=0,
            padx=8,
            pady=2,
            cursor="hand2",
            command=self._toggle_minimize_left_panel
        )
        self.min_btn.pack(side=tk.RIGHT)

        # Barra de Controles de Zoom y Movimiento (Pan con mouse)
        z_frame = tk.Frame(self.left_frame, bg="#181926")
        z_frame.pack(fill=tk.X, padx=12, pady=(2, 4))
        tk.Label(z_frame, text="Zoom:", bg="#181926", fg="#94A3B8", font=("Segoe UI", 8)).pack(side=tk.LEFT, padx=2)
        self.zoom_var = tk.StringVar(value="3x (192x384)")
        self.zoom_combo = ttk.Combobox(z_frame, textvariable=self.zoom_var, values=["1x (64x128)", "2x (128x256)", "3x (192x384)", "4x (256x512)"], state="readonly", width=13)
        self.zoom_combo.pack(side=tk.LEFT)
        self.zoom_combo.bind("<<ComboboxSelected>>", self._on_zoom_changed)

        self.center_btn = tk.Button(
            z_frame,
            text="🎯 Centrar",
            font=("Segoe UI", 8, "bold"),
            bg="#2D3250",
            fg="#E2E8F0",
            activebackground="#38BDF8",
            activeforeground="#000000",
            bd=0,
            padx=6,
            pady=2,
            cursor="hand2",
            command=self._reset_avatar_pan
        )
        self.center_btn.pack(side=tk.LEFT, padx=(6, 2))

        self.pan_lbl = tk.Label(z_frame, text="dx:0 dy:0", bg="#181926", fg="#64748B", font=("Consolas", 8))
        self.pan_lbl.pack(side=tk.LEFT, padx=2)

        # Flechas de micro-ajuste direccional
        nudge_box = tk.Frame(z_frame, bg="#181926")
        nudge_box.pack(side=tk.RIGHT)
        for arrow, (ndx, ndy) in [("◀", (-8, 0)), ("▲", (0, -8)), ("▼", (0, 8)), ("▶", (8, 0))]:
            b = tk.Button(
                nudge_box,
                text=arrow,
                font=("Segoe UI", 7, "bold"),
                bg="#1E2030",
                fg="#94A3B8",
                activebackground="#2563EB",
                activeforeground="#FFF",
                bd=0,
                padx=4,
                pady=1,
                cursor="hand2",
                command=lambda x=ndx, y=ndy: self._nudge_avatar_pan(x, y)
            )
            b.pack(side=tk.LEFT, padx=1)

        # Canvas del Avatar (soporta arrastre con mouse arriba/abajo/izq/der)
        canvas_box = tk.Frame(self.left_frame, bg="#0D0E15", bd=2, relief="sunken")
        canvas_box.pack(fill=tk.BOTH, expand=True, padx=12, pady=4)
        self.canvas = tk.Canvas(canvas_box, bg="#0D0E15", highlightthickness=0, cursor="fleur")
        self.canvas.pack(fill=tk.BOTH, expand=True)

        hint_lbl = tk.Label(
            canvas_box,
            text="🖱️ Arrastra el mouse para mover (✥) • Doble clic para centrar • Rueda para zoom",
            font=("Segoe UI", 7),
            bg="#0D0E15",
            fg="#64748B"
        )
        hint_lbl.pack(side=tk.BOTTOM, fill=tk.X, pady=(0, 2))

        # Eventos de ratón para mover el personaje arriba/abajo/izquierda/derecha
        self.canvas.bind("<ButtonPress-1>", self._on_canvas_drag_start)
        self.canvas.bind("<B1-Motion>", self._on_canvas_drag_motion)
        self.canvas.bind("<ButtonRelease-1>", self._on_canvas_drag_stop)

        self.canvas.bind("<ButtonPress-2>", self._on_canvas_drag_start)
        self.canvas.bind("<B2-Motion>", self._on_canvas_drag_motion)
        self.canvas.bind("<ButtonRelease-2>", self._on_canvas_drag_stop)

        self.canvas.bind("<ButtonPress-3>", self._on_canvas_drag_start)
        self.canvas.bind("<B3-Motion>", self._on_canvas_drag_motion)
        self.canvas.bind("<ButtonRelease-3>", self._on_canvas_drag_stop)

        self.canvas.bind("<Double-Button-1>", lambda e: self._reset_avatar_pan())
        self.canvas.bind("<MouseWheel>", self._on_canvas_mousewheel)
        self.canvas.bind("<Configure>", lambda e: self.update_avatar_preview())

        # BRÚJULA DE 8 DIRECCIONES (Sentido horario)
        compass_box = ttk.LabelFrame(self.left_frame, text=" 🧭 Brújula 8 Direcciones ", padding=6)
        compass_box.pack(fill=tk.X, padx=12, pady=4)

        c_grid = tk.Frame(compass_box, bg="#181926")
        c_grid.pack(anchor=tk.CENTER)

        self.dir_btns = {}
        compass_layout = [
            [(6, "6: ↖ NW"), (5, "5: ⬆ N"),  (4, "4: ↗ NE")],
            [(7, "7: ⬅ W"),  ("rot", "🔄 360°"), (3, "3: ➡ E")],
            [(8, "8: ↙ SW"), (1, "1: ⬇ S"),  (2, "2: ↘ SE")]
        ]

        for r, row in enumerate(compass_layout):
            for c, (val, txt) in enumerate(row):
                if val == "rot":
                    btn = tk.Button(c_grid, text=txt, font=("Segoe UI", 8, "bold"), bg="#8B5CF6", fg="#FFF", bd=0, padx=6, pady=4, cursor="hand2", command=self._toggle_auto_rotation)
                else:
                    btn = tk.Button(
                        c_grid, text=txt, font=("Segoe UI", 8, "bold"),
                        bg="#2563EB" if val == self.current_direction else "#262A40",
                        fg="#FFF", bd=0, padx=6, pady=4, cursor="hand2",
                        command=lambda v=val: self._set_direction(v)
                    )
                    self.dir_btns[val] = btn
                btn.grid(row=r, column=c, padx=3, pady=2, sticky="nsew")

        self.dir_lbl = tk.Label(compass_box, text=f"Dirección Actual: {DIRECTIONS[1]['name']}", font=("Segoe UI", 9, "bold"), bg="#181926", fg="#38BDF8")
        self.dir_lbl.pack(pady=(4, 0))

        # CONTROLES DE ANIMACIÓN (IDLE vs WALK)
        anim_box = ttk.LabelFrame(self.left_frame, text=" 🎬 Animación y Movimiento ", padding=6)
        anim_box.pack(fill=tk.X, padx=12, pady=4)

        mode_row = tk.Frame(anim_box, bg="#181926")
        mode_row.pack(fill=tk.X, pady=(0, 4))

        self.action_var = tk.StringVar(value="walk")
        tk.Radiobutton(mode_row, text="🚶 Caminar (4F)", value="walk", variable=self.action_var, bg="#181926", fg="#38BDF8", selectcolor="#2D3250", font=("Segoe UI", 8, "bold"), command=self._on_action_changed).pack(side=tk.LEFT, padx=1)
        tk.Radiobutton(mode_row, text="🧍 Detenido", value="idle", variable=self.action_var, bg="#181926", fg="#E2E8F0", selectcolor="#2D3250", font=("Segoe UI", 8), command=self._on_action_changed).pack(side=tk.LEFT, padx=3)
        tk.Radiobutton(mode_row, text="🪑 Sentado (3F)", value="sit", variable=self.action_var, bg="#181926", fg="#F59E0B", selectcolor="#2D3250", font=("Segoe UI", 8, "bold"), command=self._on_action_changed).pack(side=tk.LEFT, padx=1)

        f_row = tk.Frame(anim_box, bg="#181926")
        f_row.pack(fill=tk.X)

        self.play_btn = tk.Button(f_row, text="⏸ Pausar", font=("Segoe UI", 9, "bold"), bg="#DC2626", fg="#FFF", bd=0, padx=8, pady=3, cursor="hand2", command=self._toggle_play)
        self.play_btn.pack(side=tk.LEFT, padx=2)

        tk.Button(f_row, text="⏮", font=("Segoe UI", 8), bg="#334155", fg="#FFF", bd=0, padx=5, pady=3, command=self._prev_frame).pack(side=tk.LEFT, padx=1)
        self.step_lbl = tk.Label(f_row, text="Paso 1/4", bg="#1E2030", fg="#38BDF8", font=("Segoe UI", 8, "bold"), width=8)
        self.step_lbl.pack(side=tk.LEFT, padx=1)
        tk.Button(f_row, text="⏭", font=("Segoe UI", 8), bg="#334155", fg="#FFF", bd=0, padx=5, pady=3, command=self._next_frame).pack(side=tk.LEFT, padx=1)

        tk.Label(f_row, text="FPS:", bg="#181926", fg="#94A3B8", font=("Segoe UI", 8)).pack(side=tk.LEFT, padx=(8, 2))
        self.fps_scale = tk.Scale(f_row, from_=2, to=15, orient=tk.HORIZONTAL, bg="#181926", fg="#E2E8F0", highlightthickness=0, bd=0, length=70, showvalue=True, command=self._on_fps_changed)
        self.fps_scale.set(self.fps)
        self.fps_scale.pack(side=tk.LEFT, padx=2)

        act_bar = tk.Frame(self.left_frame, bg="#181926")
        act_bar.pack(fill=tk.X, padx=12, pady=(4, 8))

        tk.Button(act_bar, text="🎲 Aleatorio", font=("Segoe UI", 8, "bold"), bg="#8B5CF6", fg="#FFF", bd=0, padx=6, pady=4, cursor="hand2", command=self._randomize_avatar).pack(side=tk.LEFT, expand=True, fill=tk.X, padx=1)
        tk.Button(act_bar, text="🔄 Recargar Disco", font=("Segoe UI", 8), bg="#0D9488", fg="#FFF", bd=0, padx=6, pady=4, cursor="hand2", command=self._reload_catalog).pack(side=tk.LEFT, expand=True, fill=tk.X, padx=1)

        # =====================================================================
        # PANEL DERECHO: PESTAÑAS
        # =====================================================================
        self.right_frame = tk.Frame(self.main_paned, bg="#181926")
        self.main_paned.add(self.right_frame, minsize=620)

        self.notebook = ttk.Notebook(self.right_frame)
        self.notebook.pack(fill=tk.BOTH, expand=True, padx=6, pady=6)

        self._build_tab_wardrobe()
        self._build_tab_furniture_inspector()
        self._build_tab_pixellab_ai()
        self._build_tab_exports()

    # =========================================================================
    # TAB 1: ARMARIO Y PERSONALIZACIÓN DE CAPAS
    # =========================================================================
    def _build_tab_wardrobe(self):
        tab = ttk.Frame(self.notebook, padding=8)
        self.notebook.add(tab, text="👤 Armario & Capas")

        canvas = tk.Canvas(tab, bg="#181926", highlightthickness=0)
        scrollbar = ttk.Scrollbar(tab, orient="vertical", command=canvas.yview)
        scroll_frame = ttk.Frame(canvas)

        scroll_frame.bind("<Configure>", lambda e: canvas.configure(scrollregion=canvas.bbox("all")))
        canvas.create_window((0, 0), window=scroll_frame, anchor="nw")
        canvas.configure(yscrollcommand=scrollbar.set)

        canvas.pack(side="left", fill="both", expand=True)
        scrollbar.pack(side="right", fill="y")

        self._build_layer_selector_card(scroll_frame, "1. Cuerpo Base & Tono de Piel", "body", RETRO_PALETTES["skin"], "skin")
        self._build_layer_selector_card(scroll_frame, "2. Forma de Cabeza", "head", None, None)
        self._build_layer_selector_card(scroll_frame, "3. Peinado (Doble Capa Front/Back)", "hair", RETRO_PALETTES["hair"], "hair")
        self._build_layer_selector_card(scroll_frame, "4. Ojos & Pupilera (Rojo en PNG)", "eyes", RETRO_PALETTES["eyes"], "eyes")
        self._build_eyebrows_color_card(scroll_frame)
        self._build_eyeshadow_color_card(scroll_frame)
        self._build_layer_selector_card(scroll_frame, "5. Nariz (Sincronizada con piel)", "nose", None, None)
        self._build_layer_selector_card(scroll_frame, "6. Boca", "mouth", None, None)
        self._build_layer_selector_card(scroll_frame, "7. Prenda Superior (Tops)", "tops", RETRO_PALETTES["clothing"], "clothing")
        self._build_layer_selector_card(scroll_frame, "8. Prenda Inferior (Bottoms)", "bottoms", RETRO_PALETTES["clothing"], "clothing")
        self._build_layer_selector_card(scroll_frame, "9. Calzado (Shoes)", "shoes", RETRO_PALETTES["clothing"], "clothing")
        self._build_layer_selector_card(scroll_frame, "10. Accesorios", "accessories", RETRO_PALETTES["clothing"], "clothing")

    def _build_eyebrows_color_card(self, parent):
        card = ttk.LabelFrame(parent, text=" 4.1. Color de Cejas (Verde en PNG) ", padding=8)
        card.pack(fill=tk.X, expand=True, pady=4, padx=4)

        top_row = tk.Frame(card, bg="#181926")
        top_row.pack(fill=tk.X, pady=(0, 4))

        tk.Label(top_row, text="Color Cejas:", font=("Segoe UI", 8, "bold"), bg="#181926", fg="#94A3B8").pack(side=tk.LEFT, padx=2)

        curr_color = self.config.get("eyebrows", {}).get("color", "#C85A2A")
        color_prev = tk.Canvas(top_row, width=22, height=18, bg=curr_color, highlightthickness=1, highlightbackground="#475569")
        color_prev.pack(side=tk.LEFT, padx=(8, 4))

        def pick_color():
            c_data = colorchooser.askcolor(color=self.config.get("eyebrows", {}).get("color", "#C85A2A"), title="Elegir Color de Cejas")
            if c_data and c_data[1]:
                new_hex = c_data[1].upper()
                if "eyebrows" not in self.config: self.config["eyebrows"] = {}
                self.config["eyebrows"]["color"] = new_hex
                color_prev.config(bg=new_hex)
                self.update_avatar_preview()

        tk.Button(top_row, text="🎨 Color...", font=("Segoe UI", 8), bg="#3B82F6", fg="#FFF", bd=0, padx=6, pady=2, cursor="hand2", command=pick_color).pack(side=tk.LEFT, padx=2)

        def sync_hair():
            hair_c = self.config.get("hair", {}).get("color", "#C85A2A")
            if "eyebrows" not in self.config: self.config["eyebrows"] = {}
            self.config["eyebrows"]["color"] = hair_c
            color_prev.config(bg=hair_c)
            self.update_avatar_preview()

        tk.Button(top_row, text="🔗 Igual al Pelo", font=("Segoe UI", 8), bg="#8B5CF6", fg="#FFF", bd=0, padx=6, pady=2, cursor="hand2", command=sync_hair).pack(side=tk.LEFT, padx=4)

        swatch_row = tk.Frame(card, bg="#181926")
        swatch_row.pack(fill=tk.X, pady=(2, 0))
        for name, hex_code in RETRO_PALETTES["hair"][:12]:
            s_btn = tk.Button(
                swatch_row, bg=hex_code, activebackground=hex_code, width=2, height=1, bd=1, relief="ridge", cursor="hand2",
                command=lambda h=hex_code, cp=color_prev: self._apply_quick_eyebrow_color(h, cp)
            )
            s_btn.pack(side=tk.LEFT, padx=1)

    def _apply_quick_eyebrow_color(self, hex_code, color_prev_widget):
        if "eyebrows" not in self.config: self.config["eyebrows"] = {}
        self.config["eyebrows"]["color"] = hex_code
        color_prev_widget.config(bg=hex_code)
        self.update_avatar_preview()

    def _build_eyeshadow_color_card(self, parent):
        card = ttk.LabelFrame(parent, text=" 4.2. Sombra / Delineado de Ojos (Azul en PNG) ", padding=8)
        card.pack(fill=tk.X, expand=True, pady=4, padx=4)

        top_row = tk.Frame(card, bg="#181926")
        top_row.pack(fill=tk.X, pady=(0, 4))

        tk.Label(top_row, text="Color Sombra/Delineado:", font=("Segoe UI", 8, "bold"), bg="#181926", fg="#94A3B8").pack(side=tk.LEFT, padx=2)

        curr_color = self.config.get("eyeshadow", {}).get("color", "#2D2235")
        color_prev = tk.Canvas(top_row, width=22, height=18, bg="#12131C" if curr_color == "none" else curr_color, highlightthickness=1, highlightbackground="#475569")
        if curr_color == "none":
            color_prev.create_line(0, 0, 22, 18, fill="#EF4444", width=2)
        color_prev.pack(side=tk.LEFT, padx=(8, 4))

        def pick_color():
            initial_c = "#2D2235" if self.config.get("eyeshadow", {}).get("color") == "none" else self.config.get("eyeshadow", {}).get("color", "#2D2235")
            c_data = colorchooser.askcolor(color=initial_c, title="Elegir Color de Sombra / Delineado")
            if c_data and c_data[1]:
                new_hex = c_data[1].upper()
                if "eyeshadow" not in self.config: self.config["eyeshadow"] = {}
                self.config["eyeshadow"]["color"] = new_hex
                color_prev.delete("all")
                color_prev.config(bg=new_hex)
                self.update_avatar_preview()

        tk.Button(top_row, text="🎨 Color...", font=("Segoe UI", 8), bg="#3B82F6", fg="#FFF", bd=0, padx=6, pady=2, cursor="hand2", command=pick_color).pack(side=tk.LEFT, padx=2)

        def set_transparent():
            if "eyeshadow" not in self.config: self.config["eyeshadow"] = {}
            self.config["eyeshadow"]["color"] = "none"
            color_prev.delete("all")
            color_prev.config(bg="#12131C")
            color_prev.create_line(0, 0, 22, 18, fill="#EF4444", width=2)
            self.update_avatar_preview()

        tk.Button(top_row, text="🚫 Sin Sombra (Transparente)", font=("Segoe UI", 8, "bold"), bg="#475569", fg="#F1F5F9", bd=0, padx=6, pady=2, cursor="hand2", command=set_transparent).pack(side=tk.LEFT, padx=4)

        swatch_row = tk.Frame(card, bg="#181926")
        swatch_row.pack(fill=tk.X, pady=(2, 0))
        eyeshadow_swatches = [
            ("Delineador Carbón", "#2D2235"),
            ("Negro Profundo", "#141419"),
            ("Café Cálido", "#4A2E1B"),
            ("Sombra Piel", "#D4936A"),
            ("Sombra Cálida", "#C47D62"),
            ("Ciruela", "#582C4D"),
            ("Lavanda", "#9D7BB0"),
            ("Azul Noche", "#1E293B"),
            ("Esmeralda", "#064E3B"),
            ("Dorado", "#CA8A04"),
        ]
        for name, hex_code in eyeshadow_swatches:
            s_btn = tk.Button(
                swatch_row, bg=hex_code, activebackground=hex_code, width=2, height=1, bd=1, relief="ridge", cursor="hand2",
                command=lambda h=hex_code, cp=color_prev: self._apply_quick_eyeshadow_color(h, cp)
            )
            s_btn.pack(side=tk.LEFT, padx=1)

    def _apply_quick_eyeshadow_color(self, hex_code, color_prev_widget):
        if "eyeshadow" not in self.config: self.config["eyeshadow"] = {}
        self.config["eyeshadow"]["color"] = hex_code
        color_prev_widget.delete("all")
        color_prev_widget.config(bg=hex_code)
        self.update_avatar_preview()

    def _build_layer_selector_card(self, parent, title, category, swatch_palette, color_cat):
        card = ttk.LabelFrame(parent, text=f" {title} ", padding=8)
        card.pack(fill=tk.X, expand=True, pady=4, padx=4)

        top_row = tk.Frame(card, bg="#181926")
        top_row.pack(fill=tk.X, pady=(0, 4))

        tk.Label(top_row, text="Modelo:", font=("Segoe UI", 8, "bold"), bg="#181926", fg="#94A3B8").pack(side=tk.LEFT, padx=2)

        items = ["none"] + self.catalog.get(category, [])
        if not items:
            items = ["none"]

        curr_val = self.config.get(category, {}).get("file", "none")
        if curr_val not in items and items:
            curr_val = items[0]

        combo_var = tk.StringVar(value=curr_val)
        combo = ttk.Combobox(top_row, textvariable=combo_var, values=items, state="readonly", width=18)
        combo.pack(side=tk.LEFT, padx=4)
        combo.bind("<<ComboboxSelected>>", lambda e, cat=category, cv=combo_var: self._on_layer_item_selected(cat, cv.get()))

        if swatch_palette and color_cat:
            curr_color = self.config.get(category, {}).get("color", "#FFFFFF")
            color_prev = tk.Canvas(top_row, width=22, height=18, bg=curr_color, highlightthickness=1, highlightbackground="#475569")
            color_prev.pack(side=tk.LEFT, padx=(8, 4))

            def pick_color():
                c_data = colorchooser.askcolor(color=self.config[category]["color"], title=f"Elegir color para {title}")
                if c_data and c_data[1]:
                    new_hex = c_data[1].upper()
                    self.config[category]["color"] = new_hex
                    color_prev.config(bg=new_hex)
                    self.update_avatar_preview()

            tk.Button(top_row, text="🎨 Color...", font=("Segoe UI", 8), bg="#3B82F6", fg="#FFF", bd=0, padx=6, pady=2, cursor="hand2", command=pick_color).pack(side=tk.LEFT, padx=2)

            swatch_row = tk.Frame(card, bg="#181926")
            swatch_row.pack(fill=tk.X, pady=(2, 0))
            for name, hex_code in swatch_palette[:12]:
                s_btn = tk.Button(
                    swatch_row, bg=hex_code, activebackground=hex_code, width=2, height=1, bd=1, relief="ridge", cursor="hand2",
                    command=lambda h=hex_code, cat=category, cp=color_prev: self._apply_quick_color(cat, h, cp)
                )
                s_btn.pack(side=tk.LEFT, padx=1)

    def _apply_quick_color(self, category, hex_code, color_prev_widget):
        self.config[category]["color"] = hex_code
        color_prev_widget.config(bg=hex_code)
        self.update_avatar_preview()

    def _on_layer_item_selected(self, category, item_name):
        self.config[category]["file"] = item_name
        self.update_avatar_preview()

    def _on_action_changed(self):
        self.current_action = self.action_var.get()
        self.update_avatar_preview()

    # =========================================================================
    # TAB 2: CREADOR CON PIXELLAB API
    # =========================================================================
    def _build_tab_pixellab_ai(self):
        tab = ttk.Frame(self.notebook, padding=12)
        self.notebook.add(tab, text="🤖 Creador PixelLab API")

        key_box = ttk.LabelFrame(tab, text=" 🔑 Configuración de PixelLab API ", padding=8)
        key_box.pack(fill=tk.X, pady=(0, 8))

        k_row = tk.Frame(key_box, bg="#181926")
        k_row.pack(fill=tk.X)

        tk.Label(k_row, text="API Key:", font=("Segoe UI", 8, "bold"), bg="#181926", fg="#94A3B8").pack(side=tk.LEFT, padx=2)
        self.api_key_var = tk.StringVar(value=load_pixellab_key())
        self.api_entry = tk.Entry(k_row, textvariable=self.api_key_var, show="*", font=("Consolas", 9), bg="#12131C", fg="#38BDF8", insertbackground="#38BDF8", bd=1)
        self.api_entry.pack(side=tk.LEFT, fill=tk.X, expand=True, padx=4)

        save_key_btn = tk.Button(k_row, text="💾 Guardar", font=("Segoe UI", 8, "bold"), bg="#059669", fg="#FFF", bd=0, padx=8, pady=2, cursor="hand2", command=self._save_api_key)
        save_key_btn.pack(side=tk.LEFT, padx=2)

        test_key_btn = tk.Button(k_row, text="🔌 Probar Conexión", font=("Segoe UI", 8), bg="#0284C7", fg="#FFF", bd=0, padx=8, pady=2, cursor="hand2", command=self._test_pixellab_connection)
        test_key_btn.pack(side=tk.LEFT, padx=2)

        self.api_status_lbl = tk.Label(key_box, text="Estado: No verificada", font=("Segoe UI", 8), bg="#181926", fg="#94A3B8")
        self.api_status_lbl.pack(anchor=tk.W, pady=(4, 0))

        gen_box = ttk.LabelFrame(tab, text=" ✨ Generador de Ropa / Peinados / Animaciones con PixelLab ", padding=10)
        gen_box.pack(fill=tk.BOTH, expand=True, pady=4)

        p_row1 = tk.Frame(gen_box, bg="#181926")
        p_row1.pack(fill=tk.X, pady=4)

        tk.Label(p_row1, text="Categoría:", font=("Segoe UI", 8, "bold"), bg="#181926", fg="#F1F5F9").pack(side=tk.LEFT, padx=2)
        self.ai_cat_var = tk.StringVar(value="tops")
        ai_cat_combo = ttk.Combobox(p_row1, textvariable=self.ai_cat_var, values=["body", "tops", "bottoms", "shoes", "hair", "accessories"], state="readonly", width=14)
        ai_cat_combo.pack(side=tk.LEFT, padx=4)

        tk.Label(p_row1, text="Nombre del Asset:", font=("Segoe UI", 8, "bold"), bg="#181926", fg="#F1F5F9").pack(side=tk.LEFT, padx=(12, 2))
        self.ai_name_var = tk.StringVar(value="leather_jacket")
        tk.Entry(p_row1, textvariable=self.ai_name_var, font=("Segoe UI", 9), bg="#12131C", fg="#FFF", insertbackground="#FFF", width=20, bd=1).pack(side=tk.LEFT, padx=4)

        tk.Label(gen_box, text="Prompt (PixelLab generará la ropa o animación completa):", font=("Segoe UI", 8, "bold"), bg="#181926", fg="#38BDF8").pack(anchor=tk.W, pady=(8, 2))
        self.ai_prompt_text = tk.Text(gen_box, height=4, font=("Segoe UI", 9), bg="#12131C", fg="#FFF", insertbackground="#38BDF8", bd=1, padx=6, pady=6)
        self.ai_prompt_text.pack(fill=tk.X, pady=(0, 4))
        self.ai_prompt_text.insert("1.0", "vintage brown leather jacket with brass zippers, adventurer style, 16-bit SNES pixel art")

        # Tipo de Salida
        type_box = tk.Frame(gen_box, bg="#181926")
        type_box.pack(fill=tk.X, pady=4)

        self.ai_mode_var = tk.StringVar(value="animated")
        tk.Radiobutton(type_box, text="🏃 Generar Caminata Animada (4 Frames: _walk_f1 .. _walk_f4)", value="animated", variable=self.ai_mode_var, bg="#181926", fg="#38BDF8", selectcolor="#2D3250", font=("Segoe UI", 8, "bold")).pack(side=tk.LEFT, padx=4)
        tk.Radiobutton(type_box, text="🧍 Pose Detenida (1 Frame)", value="static", variable=self.ai_mode_var, bg="#181926", fg="#E2E8F0", selectcolor="#2D3250", font=("Segoe UI", 8)).pack(side=tk.LEFT, padx=8)

        # Alcance
        scope_box = tk.Frame(gen_box, bg="#181926")
        scope_box.pack(fill=tk.X, pady=4)

        self.ai_scope_var = tk.StringVar(value="current")
        tk.Radiobutton(scope_box, text="🎯 Solo Dirección Actual", value="current", variable=self.ai_scope_var, bg="#181926", fg="#E2E8F0", selectcolor="#2D3250", font=("Segoe UI", 8)).pack(side=tk.LEFT, padx=4)
        tk.Radiobutton(scope_box, text="🌐 Generar las 8 Direcciones Completas", value="all_8", variable=self.ai_scope_var, bg="#181926", fg="#38BDF8", selectcolor="#2D3250", font=("Segoe UI", 8, "bold")).pack(side=tk.LEFT, padx=8)

        self.btn_gen_ai = tk.Button(gen_box, text="⚡ GENERAR CON PIXELLAB API", font=("Segoe UI", 10, "bold"), bg="#2563EB", fg="#FFF", bd=0, pady=8, cursor="hand2", command=self._start_ai_generation_thread)
        self.btn_gen_ai.pack(fill=tk.X, pady=6)

        self.ai_result_bar = tk.Frame(gen_box, bg="#1E2030", padx=8, pady=6)
        self.ai_result_bar.pack(fill=tk.X, pady=4)

        self.ai_status_msg = tk.Label(self.ai_result_bar, text="Listo para conectar con PixelLab.", font=("Segoe UI", 8), bg="#1E2030", fg="#94A3B8")
        self.ai_status_msg.pack(side=tk.LEFT)

        self.btn_accept_save = tk.Button(self.ai_result_bar, text="💾 Aceptar y Guardar en OCTOPLAYER", font=("Segoe UI", 9, "bold"), bg="#16A34A", fg="#FFF", bd=0, padx=8, pady=3, cursor="hand2", state="disabled", command=self._accept_and_save_ai_item)
        self.btn_accept_save.pack(side=tk.RIGHT)

    def _save_api_key(self):
        k = self.api_key_var.get().strip()
        save_pixellab_key(k)
        self.pixellab_client.api_key = k
        self.api_status_lbl.config(text="✓ API Key guardada en pixellab_config.json", fg="#10B981")

    def _test_pixellab_connection(self):
        self._save_api_key()
        self.api_status_lbl.config(text="⏳ Probando conexión...", fg="#38BDF8")
        res = self.pixellab_client.test_connection()
        if res["success"]:
            self.api_status_lbl.config(text=f"🟢 Conexión exitosa con PixelLab: {res.get('message', 'OK')}", fg="#10B981")
        else:
            self.api_status_lbl.config(text=f"🔴 Error: {res['message']}", fg="#EF4444")

    def _start_ai_generation_thread(self):
        prompt = self.ai_prompt_text.get("1.0", "end").strip()
        if not prompt:
            messagebox.showwarning("Prompt Vacío", "Por favor escribe una descripción para el diseño.")
            return

        api_k = self.api_key_var.get().strip()
        if not api_k:
            messagebox.showwarning("API Key Requerida", "Por favor ingresa tu API Key de PixelLab en la parte superior.")
            return

        self._save_api_key()
        self.btn_gen_ai.config(state="disabled", text="⏳ Generando con PixelLab...", bg="#475569")
        self.ai_status_msg.config(text="PixelLab está procesando la solicitud...", fg="#38BDF8")

        thread = threading.Thread(target=self._run_ai_generation, daemon=True)
        thread.start()

    def _run_ai_generation(self):
        prompt = self.ai_prompt_text.get("1.0", "end").strip()
        category = self.ai_cat_var.get()
        item_name = self.ai_name_var.get().strip()
        scope = self.ai_scope_var.get()
        mode = self.ai_mode_var.get()

        generated_dict = {}

        try:
            body_file = self.config.get("body", {}).get("file", "female")

            if scope == "current":
                dirs_to_gen = [self.current_direction]
            else:
                dirs_to_gen = list(range(1, 9))

            for d in dirs_to_gen:
                self.ai_status_msg.config(text=f"Generando dirección {d}/8 ({DIRECTIONS[d]['name']})...")
                base_img = octo_engine.load_octo_layer("body", body_file, d, action="idle", frame=0)
                if not base_img:
                    base_img = Image.new("RGBA", (64, 128), (0, 0, 0, 0))

                if mode == "animated":
                    frames_list = self.pixellab_client.generate_animated_walk_cycle(prompt, category, base_img, d, frame_count=4)
                    generated_dict[d] = frames_list
                else:
                    layer_sprite = self.pixellab_client.generate_layer_sprite(prompt, category, base_img, d)
                    generated_dict[d] = [layer_sprite]

            self.pending_ai_layer = {
                "category": category,
                "name": item_name,
                "frames_by_dir": generated_dict
            }

            self.root.after(0, self._on_ai_generation_success)

        except Exception as e:
            self.root.after(0, lambda err=e: self._on_ai_generation_error(err))

    def _on_ai_generation_success(self):
        self.btn_gen_ai.config(state="normal", text="⚡ GENERAR CON PIXELLAB API", bg="#2563EB")
        self.btn_accept_save.config(state="normal")
        self.ai_status_msg.config(text="✨ ¡Generación completada! Vista previa activa en el canvas.", fg="#10B981")
        self.update_avatar_preview()

    def _on_ai_generation_error(self, err):
        self.btn_gen_ai.config(state="normal", text="⚡ GENERAR CON PIXELLAB API", bg="#2563EB")
        self.ai_status_msg.config(text=f"X Error: {err}", fg="#EF4444")
        messagebox.showerror("Error en Generación", f"No se pudo generar con PixelLab:\n{err}")

    def _accept_and_save_ai_item(self):
        if not self.pending_ai_layer:
            return

        cat = self.pending_ai_layer["category"]
        name = self.pending_ai_layer["name"]
        frames_dict = self.pending_ai_layer["frames_by_dir"]

        self.pixellab_client.save_item_to_octoplayer(cat, name, frames_dict)

        messagebox.showinfo("Guardado Exitoso", f"Los frames para '{name}' se guardaron correctamente en OCTOPLAYER/{cat}/.")
        self.btn_accept_save.config(state="disabled")
        self.ai_status_msg.config(text=f"✓ '{name}' añadido al armario.", fg="#10B981")

        self._reload_catalog()
        self.config[cat]["file"] = name
        self.pending_ai_layer = None
        self.update_avatar_preview()

    # =========================================================================
    # TAB 3: EXPORTAR & PRESETS
    # =========================================================================
    def _build_tab_exports(self):
        tab = ttk.Frame(self.notebook, padding=12)
        self.notebook.add(tab, text="💾 Exportar & Presets")

        p_box = ttk.LabelFrame(tab, text=" Guardar / Cargar Configuración de Avatar ", padding=10)
        p_box.pack(fill=tk.X, pady=(0, 10))

        p_row = tk.Frame(p_box, bg="#181926")
        p_row.pack(fill=tk.X)

        tk.Button(p_row, text="💾 Guardar Preset JSON", font=("Segoe UI", 9, "bold"), bg="#059669", fg="#FFF", bd=0, padx=10, pady=4, cursor="hand2", command=self._save_preset).pack(side=tk.LEFT, padx=4)
        tk.Button(p_row, text="📂 Cargar Preset JSON", font=("Segoe UI", 9), bg="#0284C7", fg="#FFF", bd=0, padx=10, pady=4, cursor="hand2", command=self._load_preset).pack(side=tk.LEFT, padx=4)

        exp_box = ttk.LabelFrame(tab, text=" 🖼️ Exportación de Sprites y Animación ", padding=10)
        exp_box.pack(fill=tk.BOTH, expand=True, pady=4)

        tk.Button(exp_box, text="📸 Exportar Frame Actual (PNG 64x128)", font=("Segoe UI", 9, "bold"), bg="#2563EB", fg="#FFF", bd=0, pady=6, cursor="hand2", command=self._export_current_png).pack(fill=tk.X, pady=4)
        tk.Button(exp_box, text="🗺️ Exportar Spritesheet 8 Direcciones (Matriz 8x4)", font=("Segoe UI", 9, "bold"), bg="#8B5CF6", fg="#FFF", bd=0, pady=6, cursor="hand2", command=self._export_spritesheet_8x4).pack(fill=tk.X, pady=4)
        tk.Button(exp_box, text="🎞️ Exportar GIF Animado 8D", font=("Segoe UI", 9, "bold"), bg="#D97706", fg="#FFF", bd=0, pady=6, cursor="hand2", command=self._export_animated_gif).pack(fill=tk.X, pady=4)

    def _save_preset(self):
        path = filedialog.asksaveasfilename(initialdir=PRESETS_DIR, defaultextension=".json", filetypes=[("JSON Files", "*.json")])
        if path:
            with open(path, "w", encoding="utf-8") as f:
                json.dump(self.config, f, indent=2)
            messagebox.showinfo("Guardado", f"Preset guardado en:\n{path}")

    def _load_preset(self):
        path = filedialog.askopenfilename(initialdir=PRESETS_DIR, filetypes=[("JSON Files", "*.json")])
        if path:
            with open(path, "r", encoding="utf-8") as f:
                self.config = json.load(f)
            self.update_avatar_preview()
            messagebox.showinfo("Cargado", "Preset cargado exitosamente.")

    def _export_current_png(self):
        img = octo_engine.compose_octo_avatar(self.config, direction=self.current_direction, action=self.current_action, frame=self.current_frame)
        path = filedialog.asksaveasfilename(initialdir=EXPORTS_DIR, defaultextension=".png", filetypes=[("PNG Files", "*.png")])
        if path:
            img.save(path)
            messagebox.showinfo("Exportado", f"PNG guardado en:\n{path}")

    def _export_spritesheet_8x4(self):
        cell_w, cell_h = 64, 128
        sheet = Image.new("RGBA", (cell_w * 4, cell_h * 8), (0, 0, 0, 0))

        for d_idx in range(1, 9):
            for f_idx in range(4):
                f_img = octo_engine.compose_octo_avatar(self.config, direction=d_idx, action="walk", frame=f_idx)
                sheet.paste(f_img, (f_idx * cell_w, (d_idx - 1) * cell_h), f_img)

        path = filedialog.asksaveasfilename(initialdir=EXPORTS_DIR, defaultextension=".png", initialfile="octo_avatar_spritesheet_8x4.png", filetypes=[("PNG Files", "*.png")])
        if path:
            sheet.save(path)
            messagebox.showinfo("Spritesheet Exportado", f"Matriz 8x4 guardada en:\n{path}\nTamaño: {sheet.size}")

    def _export_animated_gif(self):
        frames = []
        for d_idx in range(1, 9):
            for f_idx in range(4):
                img = octo_engine.compose_octo_avatar(self.config, direction=d_idx, action="walk", frame=f_idx)
                frames.append(img)

        path = filedialog.asksaveasfilename(initialdir=EXPORTS_DIR, defaultextension=".gif", initialfile="octo_walk_8d.gif", filetypes=[("GIF Files", "*.gif")])
        if path and frames:
            duration = int(1000 / max(1, self.fps))
            frames[0].save(path, save_all=True, append_images=frames[1:], duration=duration, loop=0, disposal=2)
            messagebox.showinfo("GIF Exportado", f"GIF animado guardado en:\n{path}")

    # =========================================================================
    # VISOR & LOOP DE ANIMACIÓN
    # =========================================================================
    def _on_action_changed(self):
        self.current_action = self.action_var.get()
        if self.current_action == "sit":
            # Forzar diagonal si no es diagonal (2: SE, 4: NE, 6: NW, 8: SW)
            if self.current_direction not in (2, 4, 6, 8):
                self.current_direction = 2 if self.current_direction in (1, 3) else (4 if self.current_direction == 5 else 6)
                self._update_dir_buttons()
            self.current_frame = 2 # frame 3: sentado fijo por defecto
            self.step_lbl.config(text=f"Paso {self.current_frame + 1}/3")
        elif self.current_action == "walk":
            self.current_frame = 0
            self.step_lbl.config(text=f"Paso {self.current_frame + 1}/4")
        else: # idle
            self.current_frame = 0
            self.step_lbl.config(text="Detenido")
        self.update_avatar_preview()

    def _start_animation_loop(self):
        if self.is_playing:
            if self.current_action == "walk":
                self.current_frame = (self.current_frame + 1) % 4
                self.step_lbl.config(text=f"Paso {self.current_frame + 1}/4")

                if self.is_auto_rotating and self.current_frame == 0:
                    self.current_direction = (self.current_direction % 8) + 1
                    self._update_dir_buttons()

                if not self.is_left_panel_minimized:
                    self.update_avatar_preview()

            elif self.current_action == "sit":
                self.current_frame = (self.current_frame + 1) % 3
                self.step_lbl.config(text=f"Paso {self.current_frame + 1}/3")
                if not self.is_left_panel_minimized:
                    self.update_avatar_preview()

        delay_ms = int(1000 / max(1, self.fps))
        self.anim_loop_id = self.root.after(delay_ms, self._start_animation_loop)

    def _toggle_play(self):
        self.is_playing = not self.is_playing
        if self.is_playing:
            self.play_btn.config(text="⏸ Pausar", bg="#DC2626")
        else:
            self.play_btn.config(text="▶ Reproducir", bg="#16A34A")

    def _toggle_auto_rotation(self):
        self.is_auto_rotating = not self.is_auto_rotating

    def _prev_frame(self):
        self.is_playing = False
        self.play_btn.config(text="▶ Reproducir", bg="#16A34A")
        if self.current_action == "sit":
            self.current_frame = (self.current_frame - 1) % 3
            self.step_lbl.config(text=f"Paso {self.current_frame + 1}/3")
        else:
            self.current_frame = (self.current_frame - 1) % 4
            self.step_lbl.config(text=f"Paso {self.current_frame + 1}/4")
        self.update_avatar_preview()

    def _next_frame(self):
        self.is_playing = False
        self.play_btn.config(text="▶ Reproducir", bg="#16A34A")
        if self.current_action == "sit":
            self.current_frame = (self.current_frame + 1) % 3
            self.step_lbl.config(text=f"Paso {self.current_frame + 1}/3")
        else:
            self.current_frame = (self.current_frame + 1) % 4
            self.step_lbl.config(text=f"Paso {self.current_frame + 1}/4")
        self.update_avatar_preview()

    # =========================================================================
    # MINIMIZACIÓN DEL PANEL DE PERSONAJE & MOVIMIENTO CON MOUSE (PAN)
    # =========================================================================
    def _toggle_minimize_left_panel(self):
        if self.is_left_panel_minimized:
            try:
                self.main_paned.forget(self.minimized_left_bar)
            except Exception:
                pass
            saved_w = self.left_panel_saved_width if self.left_panel_saved_width >= 350 else 440
            self.main_paned.add(self.left_frame, before=self.right_frame, width=saved_w, minsize=380)
            self.is_left_panel_minimized = False
            self.root.update_idletasks()
            self.update_avatar_preview()
        else:
            try:
                cur_w = self.left_frame.winfo_width()
                if cur_w > 100:
                    self.left_panel_saved_width = cur_w
            except Exception:
                self.left_panel_saved_width = 440
            self.main_paned.forget(self.left_frame)
            self.main_paned.add(self.minimized_left_bar, before=self.right_frame, width=46, minsize=46)
            self.is_left_panel_minimized = True

    def _on_canvas_drag_start(self, event):
        self.drag_start_x = event.x
        self.drag_start_y = event.y
        self.is_dragging_avatar = True
        self.canvas.config(cursor="fleur")

    def _on_canvas_drag_motion(self, event):
        if not self.is_dragging_avatar:
            return
        dx = event.x - self.drag_start_x
        dy = event.y - self.drag_start_y
        self.avatar_pan_x += dx
        self.avatar_pan_y += dy
        self.drag_start_x = event.x
        self.drag_start_y = event.y
        self._sync_pan_label()
        self.update_avatar_preview()

    def _on_canvas_drag_stop(self, event):
        self.is_dragging_avatar = False
        self.canvas.config(cursor="fleur")

    def _nudge_avatar_pan(self, dx, dy):
        self.avatar_pan_x += dx
        self.avatar_pan_y += dy
        self._sync_pan_label()
        self.update_avatar_preview()

    def _reset_avatar_pan(self):
        self.avatar_pan_x = 0
        self.avatar_pan_y = 0
        self._sync_pan_label()
        self.update_avatar_preview()

    def _sync_pan_label(self):
        if hasattr(self, "pan_lbl"):
            if self.avatar_pan_x == 0 and self.avatar_pan_y == 0:
                self.pan_lbl.config(text="dx:0 dy:0", fg="#64748B")
            else:
                self.pan_lbl.config(text=f"dx:{self.avatar_pan_x} dy:{self.avatar_pan_y}", fg="#38BDF8")

    def _on_canvas_mousewheel(self, event):
        old_zoom = self.zoom_level
        if event.delta > 0:
            if self.zoom_level < 4:
                self.zoom_level += 1
        elif event.delta < 0:
            if self.zoom_level > 1:
                self.zoom_level -= 1
        if self.zoom_level != old_zoom:
            self.zoom_combo.current(self.zoom_level - 1)
            self.update_avatar_preview()

    # =========================================================================
    # TAB: VERIFICADOR DE MUEBLES, BALDOSAS Y SUPERFICIES (new_added EXCLUSIVO)
    # =========================================================================
    def _build_tab_furniture_inspector(self):
        tab = ttk.Frame(self.notebook, padding=6)
        self.notebook.add(tab, text="🛋️ Muebles & Baldosas")

        paned = tk.PanedWindow(tab, orient=tk.HORIZONTAL, bg="#181926", bd=0, sashwidth=4)
        paned.pack(fill=tk.BOTH, expand=True)

        # ---------------------------------------------------------------------
        # LADO IZQUIERDO: CANVAS DE INSPECCIÓN ISOMÉTRICA & AJUSTE DE BALDOSA
        # ---------------------------------------------------------------------
        left_p = tk.Frame(paned, bg="#181926", width=460)
        paned.add(left_p, minsize=420)

        # Barra Superior de Controles de Visualización
        view_bar = tk.Frame(left_p, bg="#181926")
        view_bar.pack(fill=tk.X, pady=(0, 4))

        tk.Label(view_bar, text="Zoom:", bg="#181926", fg="#94A3B8", font=("Segoe UI", 8)).pack(side=tk.LEFT, padx=2)
        z_combo = ttk.Combobox(view_bar, values=["1x", "2x", "3x", "4x"], state="readonly", width=5)
        z_combo.set(f"{self.furn_zoom}x")
        z_combo.pack(side=tk.LEFT, padx=2)
        def on_fz_change(e):
            val = z_combo.get()
            self.furn_zoom = int(val[0])
            self._update_furniture_preview()
        z_combo.bind("<<ComboboxSelected>>", on_fz_change)

        tk.Checkbutton(view_bar, text="Baldosa", variable=self.show_tiles_var, bg="#181926", fg="#38BDF8", selectcolor="#2D3250", font=("Segoe UI", 8), command=self._update_furniture_preview).pack(side=tk.LEFT, padx=3)
        tk.Checkbutton(view_bar, text="Subcuadros", variable=self.show_subcells_var, bg="#181926", fg="#94A3B8", selectcolor="#2D3250", font=("Segoe UI", 8), command=self._update_furniture_preview).pack(side=tk.LEFT, padx=3)
        tk.Checkbutton(view_bar, text="Bounding Box", variable=self.show_bbox_var, bg="#181926", fg="#94A3B8", selectcolor="#2D3250", font=("Segoe UI", 8), command=self._update_furniture_preview).pack(side=tk.LEFT, padx=3)
        tk.Checkbutton(view_bar, text="Avatar Sentado", variable=self.show_avatar_on_furn_var, bg="#181926", fg="#F59E0B", selectcolor="#2D3250", font=("Segoe UI", 8, "bold"), command=self._update_furniture_preview).pack(side=tk.LEFT, padx=3)
        tk.Checkbutton(view_bar, text="Avatar Acostado", variable=self.show_lying_var, bg="#181926", fg="#A78BFA", selectcolor="#2D3250", font=("Segoe UI", 8, "bold"), command=self._update_furniture_preview).pack(side=tk.LEFT, padx=3)

        # Canvas de Inspección Isométrica
        canvas_box = tk.Frame(left_p, bg="#10111A", bd=2, relief="sunken")
        canvas_box.pack(fill=tk.BOTH, expand=True, pady=2)

        self.furn_canvas = tk.Canvas(canvas_box, bg="#10111A", highlightthickness=0)
        self.furn_canvas.pack(fill=tk.BOTH, expand=True)

        # Panel de Rotación Rápida
        rot_frame = tk.Frame(left_p, bg="#1E2030", padx=6, pady=4)
        rot_frame.pack(fill=tk.X, pady=3)

        tk.Label(rot_frame, text="Rotación:", font=("Segoe UI", 8, "bold"), bg="#1E2030", fg="#38BDF8").pack(side=tk.LEFT, padx=2)
        self.furn_rot_btns = {}
        rot_labels = [(0, "0: ↙ SW"), (1, "1: ↘ SE"), (2, "2: ↗ NE"), (3, "3: ↖ NW")]
        for r_val, r_txt in rot_labels:
            btn = tk.Button(
                rot_frame, text=r_txt, font=("Segoe UI", 8, "bold"),
                bg="#2563EB" if r_val == self.selected_furn_rot else "#262A40",
                fg="#FFF", bd=0, padx=6, pady=2, cursor="hand2",
                command=lambda rv=r_val: self._set_furniture_rot(rv)
            )
            btn.pack(side=tk.LEFT, padx=2)
            self.furn_rot_btns[r_val] = btn

        tk.Button(rot_frame, text="🔄 Rotar 90° (R)", font=("Segoe UI", 8, "bold"), bg="#8B5CF6", fg="#FFF", bd=0, padx=8, pady=2, cursor="hand2", command=self._rotate_furn_step).pack(side=tk.RIGHT, padx=2)

        # Panel de Ajuste Fino de Baldosa (sprite_offset)
        nudge_box = ttk.LabelFrame(left_p, text=" 📐 Calibrador de Baldosa (sprite_offset) ", padding=4)
        nudge_box.pack(fill=tk.X, pady=2)

        n_top = tk.Frame(nudge_box, bg="#181926")
        n_top.pack(fill=tk.X)
        self.offset_lbl = tk.Label(n_top, text="Offset: dx=-32, dy=-32", font=("Consolas", 8, "bold"), bg="#181926", fg="#38BDF8")
        self.offset_lbl.pack(side=tk.LEFT, padx=2)
        tk.Button(n_top, text="🔄 Reset", font=("Segoe UI", 7), bg="#475569", fg="#FFF", bd=0, padx=4, pady=1, command=self._reset_furniture_offset).pack(side=tk.RIGHT, padx=2)

        n_ctrls = tk.Frame(nudge_box, bg="#181926")
        n_ctrls.pack(fill=tk.X, pady=2)
        tk.Label(n_ctrls, text="Paso 1px:", font=("Segoe UI", 8), bg="#181926", fg="#94A3B8").pack(side=tk.LEFT, padx=2)
        tk.Button(n_ctrls, text="◀ -1x", font=("Segoe UI", 8), bg="#2D3250", fg="#FFF", bd=0, padx=4, pady=1, command=lambda: self._nudge_furniture_offset(-1, 0)).pack(side=tk.LEFT, padx=1)
        tk.Button(n_ctrls, text="▶ +1x", font=("Segoe UI", 8), bg="#2D3250", fg="#FFF", bd=0, padx=4, pady=1, command=lambda: self._nudge_furniture_offset(1, 0)).pack(side=tk.LEFT, padx=1)
        tk.Button(n_ctrls, text="▲ -1y", font=("Segoe UI", 8), bg="#2D3250", fg="#FFF", bd=0, padx=4, pady=1, command=lambda: self._nudge_furniture_offset(0, -1)).pack(side=tk.LEFT, padx=1)
        tk.Button(n_ctrls, text="▼ +1y", font=("Segoe UI", 8), bg="#2D3250", fg="#FFF", bd=0, padx=4, pady=1, command=lambda: self._nudge_furniture_offset(0, 1)).pack(side=tk.LEFT, padx=1)

        tk.Label(n_ctrls, text="5px:", font=("Segoe UI", 8), bg="#181926", fg="#94A3B8").pack(side=tk.LEFT, padx=(6, 2))
        tk.Button(n_ctrls, text="◀◀ -5", font=("Segoe UI", 8), bg="#1E2030", fg="#FFF", bd=0, padx=4, pady=1, command=lambda: self._nudge_furniture_offset(-5, 0)).pack(side=tk.LEFT, padx=1)
        tk.Button(n_ctrls, text="▶▶ +5", font=("Segoe UI", 8), bg="#1E2030", fg="#FFF", bd=0, padx=4, pady=1, command=lambda: self._nudge_furniture_offset(5, 0)).pack(side=tk.LEFT, padx=1)
        tk.Button(n_ctrls, text="▲▲ -5", font=("Segoe UI", 8), bg="#1E2030", fg="#FFF", bd=0, padx=4, pady=1, command=lambda: self._nudge_furniture_offset(0, -5)).pack(side=tk.LEFT, padx=1)
        tk.Button(n_ctrls, text="▼▼ +5", font=("Segoe UI", 8), bg="#1E2030", fg="#FFF", bd=0, padx=4, pady=1, command=lambda: self._nudge_furniture_offset(0, 5)).pack(side=tk.LEFT, padx=1)

        save_offset_btn = tk.Button(
            nudge_box,
            text="💾 Guardar Offset en Catálogo (frontend)",
            font=("Segoe UI", 8, "bold"),
            bg="#2563EB",
            fg="#FFF",
            bd=0,
            pady=3,
            cursor="hand2",
            command=self._save_offset_to_catalog
        )
        save_offset_btn.pack(fill=tk.X, pady=(4, 1))

        # ---------------------------------------------------------------------
        # LADO DERECHO: CATÁLOGO new_added & CALIBRADORES ESPECIALES
        # ---------------------------------------------------------------------
        right_p = tk.Frame(paned, bg="#181926", padx=6)
        paned.add(right_p, minsize=400)

        # Scrollable contenedor derecho
        r_canvas = tk.Canvas(right_p, bg="#181926", highlightthickness=0)
        r_scroll = ttk.Scrollbar(right_p, orient="vertical", command=r_canvas.yview)
        r_content = ttk.Frame(r_canvas)
        r_content.bind("<Configure>", lambda e: r_canvas.configure(scrollregion=r_canvas.bbox("all")))
        r_canvas.create_window((0, 0), window=r_content, anchor="nw")
        r_canvas.configure(yscrollcommand=r_scroll.set)
        r_canvas.pack(side="left", fill="both", expand=True)
        r_scroll.pack(side="right", fill="y")

        # 1. Filtros de Categoría de new_added
        filt_box = ttk.LabelFrame(r_content, text=" 📂 Catálogo Exclusivo (furniture/new_added) ", padding=6)
        filt_box.pack(fill=tk.X, pady=(0, 4))

        f_row = tk.Frame(filt_box, bg="#181926")
        f_row.pack(fill=tk.X, pady=2)
        filters = [
            ("🌟 Todos", "all"), ("📦 0.5x0.5", "0.5x0.5"), ("🪑 1x1", "1x1"),
            ("🛏️ 1x2/2x1", "1x2_2x1"), ("👑 2x2", "2x2"), ("🍵 Superficie", "surface"), ("🖼️ Pared", "wall")
        ]
        self.furn_filter_btns = {}
        for f_txt, f_val in filters:
            btn = tk.Button(
                f_row, text=f_txt, font=("Segoe UI", 8),
                bg="#2563EB" if f_val == "all" else "#262A40",
                fg="#FFF", bd=0, padx=4, pady=2, cursor="hand2",
                command=lambda fv=f_val: self._set_furniture_filter(fv)
            )
            btn.pack(side=tk.LEFT, padx=1)
            self.furn_filter_btns[f_val] = btn

        tk.Button(
            f_row, text="🔄 Recargar", font=("Segoe UI", 8, "bold"),
            bg="#059669", fg="#FFF", bd=0, padx=5, pady=2, cursor="hand2",
            command=self._reload_furniture_catalog
        ).pack(side=tk.RIGHT, padx=1)

        # Selector de Mueble (Combobox)
        sel_row = tk.Frame(filt_box, bg="#181926")
        sel_row.pack(fill=tk.X, pady=4)
        tk.Label(sel_row, text="Mueble:", font=("Segoe UI", 9, "bold"), bg="#181926", fg="#38BDF8").pack(side=tk.LEFT, padx=2)

        self.furn_combo = ttk.Combobox(sel_row, textvariable=self.selected_furn_id, state="readonly", width=26)
        self.furn_combo.pack(side=tk.LEFT, padx=4, expand=True, fill=tk.X)
        self.furn_combo.bind("<<ComboboxSelected>>", self._on_furniture_selected)

        tk.Button(
            sel_row, text="🔄 Recargar", font=("Segoe UI", 8, "bold"),
            bg="#0284C7", fg="#FFF", bd=0, padx=6, pady=2, cursor="hand2",
            command=self._reload_furniture_catalog
        ).pack(side=tk.RIGHT, padx=2)

        self._populate_furniture_combo()

        # Ficha Técnica
        self.furn_info_lbl = tk.Label(filt_box, text="", font=("Segoe UI", 8), bg="#181926", fg="#94A3B8", justify=tk.LEFT)
        self.furn_info_lbl.pack(anchor=tk.W, pady=2)

        # 2. CALIBRADOR DE ASIENTOS RESPECTO AL PERSONAJE (SEATSPOT)
        self.seat_box = ttk.LabelFrame(r_content, text=" 🪑 Calibrador de Asientos (Respecto al Personaje) ", padding=8)
        self.seat_box.pack(fill=tk.X, pady=4)

        # Guía explicativa
        guide_txt = (
            "ℹ️ CÓMO CALIBRAR ASIENTOS:\n"
            "1. Sub-baldosa (subCell): Cuadrante (du, dv) donde descansa el centro del cojín.\n"
            "2. Desfase Visual (visualOffset): Ajusta dx (fondo) y dy (altura) para que el avatar\n"
            "   apoye las nalgas justo en el cojín sin flotar ni hundirse.\n"
            "3. Capas del motor: Base Mueble → Backleg (NE/NW) → Avatar → Frente (_front.png) → Manos."
        )
        tk.Label(self.seat_box, text=guide_txt, font=("Segoe UI", 8), bg="#12131C", fg="#E2E8F0", justify=tk.LEFT, padx=6, pady=4).pack(fill=tk.X, pady=(0, 6))

        # Plaza de asiento (para sofás)
        slot_row = tk.Frame(self.seat_box, bg="#181926")
        slot_row.pack(fill=tk.X, pady=2)
        tk.Label(slot_row, text="Plaza / Asiento:", font=("Segoe UI", 8, "bold"), bg="#181926", fg="#F59E0B").pack(side=tk.LEFT, padx=2)
        self.seat_slot_combo = ttk.Combobox(slot_row, values=["Plaza 0 (Principal / Izq)", "Plaza 1 (Centro)", "Plaza 2 (Der)"], state="readonly", width=24)
        self.seat_slot_combo.current(0)
        self.seat_slot_combo.pack(side=tk.LEFT, padx=4)
        self.seat_slot_combo.bind("<<ComboboxSelected>>", self._on_seat_slot_changed)

        # Controles subCell (du, dv)
        sc_row = tk.Frame(self.seat_box, bg="#181926")
        sc_row.pack(fill=tk.X, pady=2)
        tk.Label(sc_row, text="subCell (du, dv):", font=("Segoe UI", 8), bg="#181926", fg="#94A3B8").pack(side=tk.LEFT, padx=2)
        tk.Label(sc_row, text="u:", font=("Segoe UI", 8), bg="#181926", fg="#FFF").pack(side=tk.LEFT)
        u_spin = tk.Spinbox(sc_row, from_=0, to=3, textvariable=self.seat_sub_u, width=3, command=self._on_seat_param_changed)
        u_spin.pack(side=tk.LEFT, padx=2)
        tk.Label(sc_row, text="v:", font=("Segoe UI", 8), bg="#181926", fg="#FFF").pack(side=tk.LEFT)
        v_spin = tk.Spinbox(sc_row, from_=0, to=3, textvariable=self.seat_sub_v, width=3, command=self._on_seat_param_changed)
        v_spin.pack(side=tk.LEFT, padx=2)

        # Controles visualOffset
        vo_row = tk.Frame(self.seat_box, bg="#181926")
        vo_row.pack(fill=tk.X, pady=2)
        self.seat_vo_lbl = tk.Label(vo_row, text="visualOffset: dx=-2.0, dy=0.0", font=("Consolas", 8, "bold"), bg="#181926", fg="#38BDF8")
        self.seat_vo_lbl.pack(side=tk.LEFT, padx=2)

        vo_btns = tk.Frame(self.seat_box, bg="#181926")
        vo_btns.pack(fill=tk.X, pady=2)
        tk.Label(vo_btns, text="Ajustar Avatar:", font=("Segoe UI", 8), bg="#181926", fg="#94A3B8").pack(side=tk.LEFT, padx=2)
        tk.Button(vo_btns, text="◀ -1x", font=("Segoe UI", 8), bg="#2D3250", fg="#FFF", bd=0, padx=4, pady=1, command=lambda: self._nudge_seat_visual_offset(-1, 0)).pack(side=tk.LEFT, padx=1)
        tk.Button(vo_btns, text="▶ +1x", font=("Segoe UI", 8), bg="#2D3250", fg="#FFF", bd=0, padx=4, pady=1, command=lambda: self._nudge_seat_visual_offset(1, 0)).pack(side=tk.LEFT, padx=1)
        tk.Button(vo_btns, text="▲ -1y (Subir)", font=("Segoe UI", 8), bg="#2D3250", fg="#FFF", bd=0, padx=4, pady=1, command=lambda: self._nudge_seat_visual_offset(0, -1)).pack(side=tk.LEFT, padx=1)
        tk.Button(vo_btns, text="▼ +1y (Bajar)", font=("Segoe UI", 8), bg="#2D3250", fg="#FFF", bd=0, padx=4, pady=1, command=lambda: self._nudge_seat_visual_offset(0, 1)).pack(side=tk.LEFT, padx=1)
        tk.Button(vo_btns, text="▲▲ -5y", font=("Segoe UI", 8), bg="#1E2030", fg="#FFF", bd=0, padx=3, pady=1, command=lambda: self._nudge_seat_visual_offset(0, -5)).pack(side=tk.LEFT, padx=1)
        tk.Button(vo_btns, text="▼▼ +5y", font=("Segoe UI", 8), bg="#1E2030", fg="#FFF", bd=0, padx=3, pady=1, command=lambda: self._nudge_seat_visual_offset(0, 5)).pack(side=tk.LEFT, padx=1)

        copy_seat_btn = tk.Button(self.seat_box, text="📋 Copiar Configuración Dart (chair_seat_config.dart)", font=("Segoe UI", 9, "bold"), bg="#0284C7", fg="#FFF", bd=0, pady=4, cursor="hand2", command=self._copy_seat_dart_code)
        copy_seat_btn.pack(fill=tk.X, pady=(6, 2))

        # 2b. CALIBRADOR DE CAMAS (ACOSTARSE)
        self._build_bed_sleep_calibrator(r_content)

        # 3. CALIBRADOR DE SUPERFICIES (Múltiples Lugares / Spots)
        self.surf_box = ttk.LabelFrame(r_content, text=" 🍵 Calibrador de Superficies (Múltiples Spots) ", padding=8)
        self.surf_box.pack(fill=tk.X, pady=4)

        # Fila Mueble Soporte (si se inspecciona un objeto surface)
        self.sup_row = tk.Frame(self.surf_box, bg="#181926")
        self.sup_row.pack(fill=tk.X, pady=2)
        self.sup_lbl = tk.Label(self.sup_row, text="Mueble Soporte:", font=("Segoe UI", 8, "bold"), bg="#181926", fg="#38BDF8")
        self.sup_lbl.pack(side=tk.LEFT, padx=2)
        self.surf_sup_combo = ttk.Combobox(self.sup_row, textvariable=self.surface_support_id, state="readonly", width=20)
        self.surf_sup_combo.pack(side=tk.LEFT, padx=4)
        self.surf_sup_combo.bind("<<ComboboxSelected>>", self._on_support_selected)

        # Fila Selector de Spot / Lugar
        spot_nav_row = tk.Frame(self.surf_box, bg="#181926")
        spot_nav_row.pack(fill=tk.X, pady=(4, 2))
        tk.Label(spot_nav_row, text="Lugar / Spot:", font=("Segoe UI", 8, "bold"), bg="#181926", fg="#F59E0B").pack(side=tk.LEFT, padx=2)

        self.spot_btns_frame = tk.Frame(spot_nav_row, bg="#181926")
        self.spot_btns_frame.pack(side=tk.LEFT, padx=2)

        tk.Button(spot_nav_row, text="➕", font=("Segoe UI", 8, "bold"), bg="#0284C7", fg="#FFF", bd=0, padx=4, pady=1, cursor="hand2", command=self._add_surface_spot).pack(side=tk.LEFT, padx=2)
        tk.Button(spot_nav_row, text="✖", font=("Segoe UI", 8), bg="#7F1D1D", fg="#FFF", bd=0, padx=4, pady=1, cursor="hand2", command=self._delete_surface_spot).pack(side=tk.LEFT, padx=2)

        # Fila Subcuadro (u, v) del Spot seleccionado
        sc_row = tk.Frame(self.surf_box, bg="#181926")
        sc_row.pack(fill=tk.X, pady=2)
        tk.Label(sc_row, text="Subcuadro (u, v):", font=("Segoe UI", 8), bg="#181926", fg="#94A3B8").pack(side=tk.LEFT, padx=2)
        tk.Label(sc_row, text="u:", font=("Segoe UI", 8), bg="#181926", fg="#FFF").pack(side=tk.LEFT)
        self.surf_u_spin = tk.Spinbox(sc_row, from_=0, to=4, textvariable=self.surface_sub_u, width=3, command=self._on_surface_param_changed)
        self.surf_u_spin.pack(side=tk.LEFT, padx=2)
        tk.Label(sc_row, text="v:", font=("Segoe UI", 8), bg="#181926", fg="#FFF").pack(side=tk.LEFT)
        self.surf_v_spin = tk.Spinbox(sc_row, from_=0, to=4, textvariable=self.surface_sub_v, width=3, command=self._on_surface_param_changed)
        self.surf_v_spin.pack(side=tk.LEFT, padx=2)

        # Fila Objeto de prueba en este spot
        it_row = tk.Frame(self.surf_box, bg="#181926")
        it_row.pack(fill=tk.X, pady=2)
        tk.Label(it_row, text="Objeto en Spot:", font=("Segoe UI", 8), bg="#181926", fg="#94A3B8").pack(side=tk.LEFT, padx=2)
        self.spot_item_combo = ttk.Combobox(
            it_row, textvariable=self.surface_spot_item, state="readonly", width=18,
            values=["table_lamp", "coffee_mug", "open_book", "none"]
        )
        self.spot_item_combo.pack(side=tk.LEFT, padx=2)
        self.spot_item_combo.bind("<<ComboboxSelected>>", lambda e: self._on_surface_param_changed())

        # Fila Desfase fino (dx, dy) del Spot con ingreso numérico directo y paso fino 1px
        soff_row = tk.Frame(self.surf_box, bg="#181926")
        soff_row.pack(fill=tk.X, pady=2)
        tk.Label(soff_row, text="Desfase Spot:", font=("Segoe UI", 8), bg="#181926", fg="#94A3B8").pack(side=tk.LEFT, padx=2)

        tk.Label(soff_row, text="dx:", font=("Segoe UI", 8, "bold"), bg="#181926", fg="#38BDF8").pack(side=tk.LEFT, padx=(3, 0))
        self.surf_off_x_spin = tk.Spinbox(
            soff_row, from_=-128, to=128, textvariable=self.surface_off_x, width=4,
            command=self._on_surface_param_changed
        )
        self.surf_off_x_spin.pack(side=tk.LEFT, padx=1)
        self.surf_off_x_spin.bind("<KeyRelease>", self._on_surface_spin_key)

        tk.Label(soff_row, text="dy:", font=("Segoe UI", 8, "bold"), bg="#181926", fg="#38BDF8").pack(side=tk.LEFT, padx=(3, 0))
        self.surf_off_y_spin = tk.Spinbox(
            soff_row, from_=-128, to=128, textvariable=self.surface_off_y, width=4,
            command=self._on_surface_param_changed
        )
        self.surf_off_y_spin.pack(side=tk.LEFT, padx=1)
        self.surf_off_y_spin.bind("<KeyRelease>", self._on_surface_spin_key)

        # Botones de ajuste fino de 1px
        tk.Button(soff_row, text="◀ -1", font=("Segoe UI", 8), bg="#2D3250", fg="#FFF", bd=0, padx=3, pady=1, command=lambda: self._nudge_surface_offset(-1, 0)).pack(side=tk.LEFT, padx=1)
        tk.Button(soff_row, text="▶ +1", font=("Segoe UI", 8), bg="#2D3250", fg="#FFF", bd=0, padx=3, pady=1, command=lambda: self._nudge_surface_offset(1, 0)).pack(side=tk.LEFT, padx=1)
        tk.Button(soff_row, text="▲ -1", font=("Segoe UI", 8), bg="#2D3250", fg="#FFF", bd=0, padx=3, pady=1, command=lambda: self._nudge_surface_offset(0, -1)).pack(side=tk.LEFT, padx=1)
        tk.Button(soff_row, text="▼ +1", font=("Segoe UI", 8), bg="#2D3250", fg="#FFF", bd=0, padx=3, pady=1, command=lambda: self._nudge_surface_offset(0, 1)).pack(side=tk.LEFT, padx=1)

        # Fila Altura Tablero
        h_row = tk.Frame(self.surf_box, bg="#181926")
        h_row.pack(fill=tk.X, pady=2)
        tk.Label(h_row, text="Altura Tablero (surface_height):", font=("Segoe UI", 8), bg="#181926", fg="#94A3B8").pack(side=tk.LEFT, padx=2)
        h_spin = tk.Spinbox(h_row, from_=0, to=80, textvariable=self.surface_height_var, width=4, command=self._update_furniture_preview)
        h_spin.pack(side=tk.LEFT, padx=2)
        tk.Label(h_row, text="px", font=("Segoe UI", 8), bg="#181926", fg="#94A3B8").pack(side=tk.LEFT)

        # Opciones de visualización
        opt_row = tk.Frame(self.surf_box, bg="#181926")
        opt_row.pack(fill=tk.X, pady=3)
        tk.Checkbutton(
            opt_row, text="Ver todos los objetos", variable=self.show_all_surf_items_var,
            bg="#181926", fg="#E2E8F0", selectcolor="#12131C", font=("Segoe UI", 8),
            command=self._update_furniture_preview
        ).pack(side=tk.LEFT, padx=2)
        tk.Checkbutton(
            opt_row, text="Marcadores [0], [1]...", variable=self.show_surf_markers_var,
            bg="#181926", fg="#E2E8F0", selectcolor="#12131C", font=("Segoe UI", 8),
            command=self._update_furniture_preview
        ).pack(side=tk.LEFT, padx=2)

        save_surf_btn = tk.Button(
            self.surf_box,
            text="💾 Guardar Spots en Catálogo (frontend)",
            font=("Segoe UI", 9, "bold"),
            bg="#059669",
            fg="#FFF",
            bd=0,
            pady=4,
            cursor="hand2",
            command=self._save_surface_to_catalog
        )
        save_surf_btn.pack(fill=tk.X, pady=(4, 2))

        copy_surf_btn = tk.Button(
            self.surf_box,
            text="📋 Copiar Metadata JSON al Portapapeles",
            font=("Segoe UI", 8),
            bg="#334155",
            fg="#CBD5E1",
            bd=0,
            pady=2,
            cursor="hand2",
            command=self._copy_surface_json_code
        )
        copy_surf_btn.pack(fill=tk.X, pady=(2, 2))


        # Atajo tecla R para rotar
        self.root.bind("<Key-r>", self._on_key_rotate_furn)
        self.root.bind("<Key-R>", self._on_key_rotate_furn)

        # Poblar muebles de soporte y superficie, y actualizar vista inicial
        self._populate_support_combo()
        self._populate_surface_item_combo()
        self._on_furniture_selected()

    def _populate_surface_item_combo(self):
        surface_items = [fid for fid, fmeta in sorted(self.furn_catalog.items()) if fmeta.get("footprint") == "surface"]
        if not surface_items:
            surface_items = ["table_lamp", "coffee_mug", "open_book"]
        all_vals = list(surface_items)
        if "none" not in all_vals:
            all_vals.append("none")
        if hasattr(self, "spot_item_combo"):
            self.spot_item_combo["values"] = all_vals

    def _reload_furniture_catalog(self):
        self.furn_catalog = fie.scan_new_added_furniture()
        self._populate_furniture_combo()
        self._populate_support_combo()
        self._populate_surface_item_combo()
        self._on_furniture_selected()
        total_n = len(self.furn_catalog)
        surf_n = len([k for k, v in self.furn_catalog.items() if v.get("footprint") == "surface"])
        messagebox.showinfo("Catálogo Recargado", f"✅ Se re-escaneó la carpeta new_added:\n\n• Total muebles: {total_n}\n• Objetos superficie: {surf_n}\n\nLos selectores y listas han sido actualizados.")

    def _populate_furniture_combo(self):
        zone_filter = self.furn_filter_var.get()
        filtered = []
        for fid, fmeta in sorted(self.furn_catalog.items()):
            fp = fmeta.get("footprint", "1x1")
            if zone_filter == "all":
                filtered.append(fid)
            elif zone_filter == "0.5x0.5" and fp == "0.5x0.5":
                filtered.append(fid)
            elif zone_filter == "1x1" and fp == "1x1":
                filtered.append(fid)
            elif zone_filter == "1x2_2x1" and fp in ("1x2", "2x1"):
                filtered.append(fid)
            elif zone_filter == "2x2" and fp == "2x2":
                filtered.append(fid)
            elif zone_filter == "surface" and fp == "surface":
                filtered.append(fid)
            elif zone_filter == "wall" and fp == "wall":
                filtered.append(fid)

        if hasattr(self, "furn_combo"):
            self.furn_combo["values"] = filtered
            if filtered and self.selected_furn_id.get() not in filtered:
                self.selected_furn_id.set(filtered[0])
                self._on_furniture_selected()

        self._populate_surface_item_combo()

    def _populate_support_combo(self):
        supports = [fid for fid, fmeta in self.furn_catalog.items() if fmeta.get("supports_surface")]
        if not supports:
            supports = ["table", "side_table", "gaming_pc_desk"]
        if hasattr(self, "surf_sup_combo"):
            self.surf_sup_combo["values"] = supports
            if supports and self.surface_support_id.get() not in supports:
                self.surface_support_id.set(supports[0])
            self._on_support_selected()

    def _on_support_selected(self, event=None):
        sup_id = self.surface_support_id.get().strip()
        sup_meta = self.furn_catalog.get(sup_id, {})
        if sup_meta:
            h = sup_meta.get("surface_height", 22)
            self.surface_height_var.set(h)
            self._load_surface_spots_for_current()
        self._update_furniture_preview()

    def _load_surface_spots_for_current(self):
        fid = self.selected_furn_id.get().strip()
        fmeta = self.furn_catalog.get(fid, {})
        rot = self.selected_furn_rot

        # Determinar si estamos configurando la mesa seleccionada o el soporte de un objeto surface
        if fmeta.get("supports_surface"):
            target_meta = fmeta
            if hasattr(self, "sup_row"):
                self.sup_lbl.config(text=f"Mesa: {fmeta.get('name', fid)[:18]}")
                self.surf_sup_combo.pack_forget()
        elif fmeta.get("footprint") == "surface":
            sup_id = self.surface_support_id.get().strip()
            target_meta = self.furn_catalog.get(sup_id, {})
            if hasattr(self, "sup_row"):
                self.sup_lbl.config(text="Mueble Soporte:")
                self.surf_sup_combo.pack(side=tk.LEFT, padx=4)
        else:
            self.current_surface_spots = []
            self._update_surface_spot_buttons()
            return

        rot_data = target_meta.get("rotations", {}).get(rot, {})
        spots = rot_data.get("surface_spots") or target_meta.get("surface_spots")
        if isinstance(spots, dict):
            spots = spots.get(rot, spots.get(str(rot), spots.get(0, [])))

        if not spots:
            fp = target_meta.get("footprint", "1x1")
            if fp == "0.5x0.5":
                spots = [{"spot": 0, "sub_cell": [0, 0], "offset": [0, 0], "item": "table_lamp"}]
            elif fp in ("2x1", "1x2"):
                spots = [
                    {"spot": 0, "sub_cell": [0, 0], "offset": [0, 0], "item": "table_lamp"},
                    {"spot": 1, "sub_cell": [1, 0] if fp == "2x1" else [0, 1], "offset": [0, 0], "item": "coffee_mug"}
                ]
            elif fp == "2x2":
                spots = [
                    {"spot": 0, "sub_cell": [1, 1], "offset": [0, 0], "item": "table_lamp"},
                    {"spot": 1, "sub_cell": [2, 1], "offset": [0, 0], "item": "coffee_mug"},
                    {"spot": 2, "sub_cell": [1, 2], "offset": [0, 0], "item": "open_book"},
                    {"spot": 3, "sub_cell": [2, 2], "offset": [0, 0], "item": "table_lamp"},
                ]
            else: # 1x1
                spots = [
                    {"spot": 0, "sub_cell": [0, 0], "offset": [0, 0], "item": "table_lamp"},
                    {"spot": 1, "sub_cell": [1, 0], "offset": [0, 0], "item": "coffee_mug"},
                    {"spot": 2, "sub_cell": [0, 1], "offset": [0, 0], "item": "open_book"},
                    {"spot": 3, "sub_cell": [1, 1], "offset": [0, 0], "item": "none"},
                ]

        self.current_surface_spots = [dict(s) for s in spots]
        self.surface_height_var.set(target_meta.get("surface_height", 22))

        # Configurar límites de u, v según huella
        fp = target_meta.get("footprint", "1x1")
        max_u, max_v = 1, 1
        if fp == "2x2": max_u, max_v = 3, 3
        elif fp in ("2x1", "1x2"): max_u, max_v = (3, 1) if fp == "2x1" else (1, 3)
        elif fp == "0.5x0.5": max_u, max_v = 0, 0

        if hasattr(self, "surf_u_spin"):
            self.surf_u_spin.config(to=max_u)
        if hasattr(self, "surf_v_spin"):
            self.surf_v_spin.config(to=max_v)

        idx = min(self.surface_spot_idx, len(self.current_surface_spots) - 1)
        self._select_surface_spot(max(0, idx))

    def _update_surface_spot_buttons(self):
        if not hasattr(self, "spot_btns_frame"):
            return
        for w in self.spot_btns_frame.winfo_children():
            w.destroy()

        for idx, s in enumerate(self.current_surface_spots):
            is_active = (idx == self.surface_spot_idx)
            bg_col = "#2563EB" if is_active else "#262A40"
            fg_col = "#FFFFFF" if is_active else "#94A3B8"
            item_name = s.get("item", "table_lamp")
            icon = "🍵" if "mug" in item_name else ("💡" if "lamp" in item_name else ("📖" if "book" in item_name else "📍"))
            btn = tk.Button(
                self.spot_btns_frame,
                text=f"{icon} {idx}",
                font=("Segoe UI", 8, "bold" if is_active else "normal"),
                bg=bg_col,
                fg=fg_col,
                bd=0,
                padx=4,
                pady=1,
                cursor="hand2",
                command=lambda i=idx: self._select_surface_spot(i)
            )
            btn.pack(side=tk.LEFT, padx=1)

    def _select_surface_spot(self, idx):
        if not self.current_surface_spots:
            return
        self.surface_spot_idx = max(0, min(idx, len(self.current_surface_spots) - 1))
        spot = self.current_surface_spots[self.surface_spot_idx]
        self.surface_sub_u.set(spot.get("sub_cell", [0, 0])[0])
        self.surface_sub_v.set(spot.get("sub_cell", [0, 0])[1])
        off = spot.get("offset", [0, 0])
        self.surface_off_x.set(off[0])
        self.surface_off_y.set(off[1])
        if hasattr(self, "surf_off_x_spin"):
            self.surf_off_x_spin.delete(0, tk.END)
            self.surf_off_x_spin.insert(0, str(off[0]))
        if hasattr(self, "surf_off_y_spin"):
            self.surf_off_y_spin.delete(0, tk.END)
            self.surf_off_y_spin.insert(0, str(off[1]))
        self.surface_spot_item.set(spot.get("item", "table_lamp"))
        self._update_surface_spot_buttons()
        if hasattr(self, "surf_off_lbl"):
            self.surf_off_lbl.config(text=f"dx={off[0]}, dy={off[1]}")
        self._update_furniture_preview()

    def _on_surface_spin_key(self, event=None):
        try:
            x_val = int(self.surf_off_x_spin.get())
            y_val = int(self.surf_off_y_spin.get())
            self.surface_off_x.set(x_val)
            self.surface_off_y.set(y_val)
            self._on_surface_param_changed()
        except (ValueError, tk.TclError):
            pass

    def _on_surface_param_changed(self):
        if not self.current_surface_spots or self.surface_spot_idx >= len(self.current_surface_spots):
            return
        try:
            ox = int(self.surface_off_x.get())
            oy = int(self.surface_off_y.get())
        except (ValueError, tk.TclError):
            return
        try:
            su = int(self.surface_sub_u.get())
            sv = int(self.surface_sub_v.get())
        except (ValueError, tk.TclError):
            return

        spot = self.current_surface_spots[self.surface_spot_idx]
        spot["sub_cell"] = [su, sv]
        spot["offset"] = [ox, oy]
        spot["item"] = self.surface_spot_item.get()
        if hasattr(self, "surf_off_lbl"):
            self.surf_off_lbl.config(text=f"dx={ox}, dy={oy}")
        self._update_furniture_preview()

    def _nudge_surface_offset(self, dx, dy):
        try:
            curr_x = int(self.surface_off_x.get())
            curr_y = int(self.surface_off_y.get())
        except (ValueError, tk.TclError):
            curr_x, curr_y = 0, 0
        new_x = curr_x + dx
        new_y = curr_y + dy
        self.surface_off_x.set(new_x)
        self.surface_off_y.set(new_y)
        if hasattr(self, "surf_off_x_spin"):
            self.surf_off_x_spin.delete(0, tk.END)
            self.surf_off_x_spin.insert(0, str(new_x))
        if hasattr(self, "surf_off_y_spin"):
            self.surf_off_y_spin.delete(0, tk.END)
            self.surf_off_y_spin.insert(0, str(new_y))
        self._on_surface_param_changed()

    def _add_surface_spot(self):
        new_idx = len(self.current_surface_spots)
        fid = self.selected_furn_id.get().strip()
        fmeta = self.furn_catalog.get(fid, {})
        sup_id = self.surface_support_id.get().strip()
        target_meta = fmeta if fmeta.get("supports_surface") else self.furn_catalog.get(sup_id, {})
        fp = target_meta.get("footprint", "1x1")

        if fp == "2x2":
            candidates = [[1, 1], [2, 1], [1, 2], [2, 2], [0, 1], [1, 0], [2, 3], [3, 2]]
        elif fp in ("2x1", "1x2"):
            candidates = [[0, 0], [1, 0], [2, 0], [0, 1], [1, 1], [2, 1]]
        elif fp == "0.5x0.5":
            candidates = [[0, 0]]
        else:
            candidates = [[0, 0], [1, 1], [1, 0], [0, 1]]

        used_cells = [s.get("sub_cell", [0, 0]) for s in self.current_surface_spots]
        new_cell = [0, 0]
        for c in candidates:
            if c not in used_cells:
                new_cell = c
                break

        items_cycle = ["table_lamp", "coffee_mug", "open_book"]
        new_item = items_cycle[new_idx % len(items_cycle)]

        self.current_surface_spots.append({
            "spot": new_idx,
            "sub_cell": new_cell,
            "offset": [0, 0],
            "item": new_item
        })
        self._select_surface_spot(new_idx)

    def _delete_surface_spot(self):
        if len(self.current_surface_spots) <= 1:
            messagebox.showinfo("Atención", "Debe haber al menos 1 lugar de superficie configurado.")
            return
        del self.current_surface_spots[self.surface_spot_idx]
        for i, s in enumerate(self.current_surface_spots):
            s["spot"] = i
        new_idx = min(self.surface_spot_idx, len(self.current_surface_spots) - 1)
        self._select_surface_spot(new_idx)

    def _set_furniture_filter(self, filter_val):
        self.furn_filter_var.set(filter_val)
        for k, btn in self.furn_filter_btns.items():
            btn.config(bg="#2563EB" if k == filter_val else "#262A40")
        self._populate_furniture_combo()

    def _on_furniture_selected(self, event=None):
        fid = self.selected_furn_id.get()
        fmeta = self.furn_catalog.get(fid, {})
        self.custom_sprite_offset = None # Usar offset por defecto del mueble

        # Cargar preset de asiento si existe
        seat_presets = fie.DEFAULT_SEAT_CONFIGS.get(fid, {})
        rot_spots = seat_presets.get(self.selected_furn_rot, [])
        if rot_spots:
            idx = min(self.seat_slot_idx, len(rot_spots) - 1)
            spot = rot_spots[idx]
            self.seat_sub_u.set(spot["sub_cell"][0])
            self.seat_sub_v.set(spot["sub_cell"][1])
            self.seat_voff_x.set(spot["visual_offset"][0])
            self.seat_voff_y.set(spot["visual_offset"][1])
            self.seat_toff_x.set(spot["tap_offset"][0])
            self.seat_toff_y.set(spot["tap_offset"][1])
        else:
            self.seat_sub_u.set(0)
            self.seat_sub_v.set(0)
            self.seat_voff_x.set(-2.0)
            self.seat_voff_y.set(0.0)

        # Configurar superficie si aplica
        if fmeta.get("supports_surface") or fmeta.get("footprint") == "surface":
            self._load_surface_spots_for_current()

        # Ficha técnica
        fp = fmeta.get("footprint", "1x1")
        is_chair = fmeta.get("is_chair", False)
        txt = (
            f"ID: {fid} | Nombre: {fmeta.get('name', fid)}\n"
            f"Huella: {fp} | Carpeta: {fmeta.get('folder', 'new_added')}\n"
            f"Tipo: {'🪑 Asiento (Interactivo)' if is_chair else ('🍵 Objeto Superficie' if fp == 'surface' else 'Mueble General')}"
        )
        if hasattr(self, "furn_info_lbl"):
            self.furn_info_lbl.config(text=txt)

        self._update_furniture_preview()

    def _set_furniture_rot(self, rot_val):
        self.selected_furn_rot = rot_val
        for k, btn in self.furn_rot_btns.items():
            btn.config(bg="#2563EB" if k == rot_val else "#262A40")

        # Cargar valores de asiento para esta rotación si existen
        fid = self.selected_furn_id.get()
        seat_presets = fie.DEFAULT_SEAT_CONFIGS.get(fid, {})
        rot_spots = seat_presets.get(rot_val, [])
        if rot_spots:
            idx = min(self.seat_slot_idx, len(rot_spots) - 1)
            spot = rot_spots[idx]
            self.seat_sub_u.set(spot["sub_cell"][0])
            self.seat_sub_v.set(spot["sub_cell"][1])
            self.seat_voff_x.set(spot["visual_offset"][0])
            self.seat_voff_y.set(spot["visual_offset"][1])
            self.seat_toff_x.set(spot["tap_offset"][0])
            self.seat_toff_y.set(spot["tap_offset"][1])

        # Cargar valores de superficie para esta rotación si aplican
        fmeta = self.furn_catalog.get(fid, {})
        if fmeta.get("supports_surface") or fmeta.get("footprint") == "surface":
            self._load_surface_spots_for_current()

        self._update_furniture_preview()


    def _rotate_furn_step(self):
        new_rot = (self.selected_furn_rot + 1) % 4
        self._set_furniture_rot(new_rot)

    def _on_key_rotate_furn(self, event=None):
        # Rotar si estamos en la pestaña de muebles
        current_tab_idx = self.notebook.index(self.notebook.select())
        if current_tab_idx == 1:
            self._rotate_furn_step()

    def _nudge_furniture_offset(self, dx, dy):
        fid = self.selected_furn_id.get()
        fmeta = self.furn_catalog.get(fid, {})
        rot_data = fmeta.get("rotations", {}).get(self.selected_furn_rot, {})
        if self.custom_sprite_offset is not None:
            base_off = self.custom_sprite_offset
        else:
            cat_off = rot_data.get("sprite_offset", [-32, -32])
            fp = fmeta.get("footprint", "1x1")
            cw, ch = rot_data.get("canvas_size", [128, 176])
            if fp == "0.5x0.5" and (cat_off in ([-32, -44], [-32, -32]) or cat_off[1] == -44):
                base_off = [-cw // 4, 8 - (ch // 2)]
            else:
                base_off = cat_off
        self.custom_sprite_offset = [base_off[0] + dx, base_off[1] + dy]
        self._update_furniture_preview()

    def _reset_furniture_offset(self):
        self.custom_sprite_offset = None
        self._update_furniture_preview()

    # ------------------------------------------------------------------ calibrador de camas
    def _build_bed_sleep_calibrator(self, parent):
        box = ttk.LabelFrame(parent, text=" 🛏️ Calibrador de Camas (Acostarse) ", padding=8)
        box.pack(fill=tk.X, pady=4)
        guide_txt = (
            "ℹ️ CÓMO CALIBRAR CAMAS:\n"
            "1. Elige una cama (single_bed / single_high_bed) y activa 'Avatar Acostado' arriba.\n"
            "2. La cruz roja es baseHead (dónde va la cabeza); la línea es el eje del cuerpo.\n"
            "   Céntrala a lo largo del colchón y con la cabeza sobre la almohada.\n"
            "3. Las flechas diagonales siguen los ejes isométricos de la cama (ancho / largo).\n"
            "4. 'Guardar' escribe bed_sleep_config.dart — en el juego haz HOT RESTART (R)."
        )
        tk.Label(box, text=guide_txt, font=("Segoe UI", 8), bg="#12131C", fg="#E2E8F0", justify=tk.LEFT, padx=6, pady=4).pack(fill=tk.X, pady=(0, 6))

        opt = tk.Frame(box, bg="#181926"); opt.pack(fill=tk.X, pady=2)
        tk.Checkbutton(opt, text="Bajo la cobija", variable=self.lie_under_var, bg="#181926", fg="#A78BFA", selectcolor="#2D3250",
                       font=("Segoe UI", 8), command=self._update_furniture_preview).pack(side=tk.LEFT, padx=2)
        for val, txt in (("male", "Hombre"), ("female", "Mujer")):
            tk.Radiobutton(opt, text=txt, value=val, variable=self.lie_body_var, bg="#181926", fg="#E2E8F0", selectcolor="#2D3250",
                           font=("Segoe UI", 8), command=self._update_furniture_preview).pack(side=tk.LEFT, padx=2)

        # Look of the preview avatar: every style that has lying art (scanned from lying/ folders)
        styles = bsc.available_styles()
        look = tk.Frame(box, bg="#181926"); look.pack(fill=tk.X, pady=2)
        rows = [
            ("Ojos", self.lie_eyes_var, styles["eyes"]),
            ("Boca", self.lie_mouth_var, styles["mouth"]),
            ("Nariz", self.lie_nose_var, styles["nose"]),
            ("Pelo", self.lie_hair_var, ["none"] + styles["hair"]),
            ("Ropa arriba", self.lie_top_var, ["none"] + styles["tops"]),
            ("Ropa abajo", self.lie_bottom_var, ["none"] + styles["bottoms"]),
        ]
        for i, (label, var, values) in enumerate(rows):
            r, c = divmod(i, 2)
            tk.Label(look, text=label + ":", font=("Segoe UI", 8), bg="#181926", fg="#94A3B8").grid(row=r, column=c * 2, sticky="e", padx=(4, 2), pady=1)
            cb = ttk.Combobox(look, values=values, textvariable=var, state="readonly", width=12)
            cb.grid(row=r, column=c * 2 + 1, sticky="w", pady=1)
            cb.bind("<<ComboboxSelected>>", lambda e: self._update_furniture_preview())
        acc_values = ["none"] + [a if has else f"{a} (sin versión acostada)" for a, has in styles["accessories"]]
        tk.Label(look, text="Accesorio:", font=("Segoe UI", 8), bg="#181926", fg="#94A3B8").grid(row=3, column=0, sticky="e", padx=(4, 2), pady=1)
        acc_cb = ttk.Combobox(look, values=acc_values, textvariable=self.lie_acc_var, state="readonly", width=30)
        acc_cb.grid(row=3, column=1, columnspan=3, sticky="w", pady=1)
        acc_cb.bind("<<ComboboxSelected>>", lambda e: self._update_furniture_preview())
        tk.Label(box, text="Los accesorios aún no tienen sprites acostados: el juego no los dibuja al acostarse.",
                 font=("Segoe UI", 7), bg="#181926", fg="#64748B").pack(anchor=tk.W)

        colors = tk.Frame(box, bg="#181926"); colors.pack(fill=tk.X, pady=2)
        tk.Checkbutton(colors, text="Colores del Armario (piel, pelo, ojos, ropa)", variable=self.lie_wardrobe_colors_var, bg="#181926",
                       fg="#94A3B8", selectcolor="#2D3250", font=("Segoe UI", 8), command=self._update_furniture_preview).pack(side=tk.LEFT, padx=2)
        tk.Button(colors, text="👤 Copiar del Armario", font=("Segoe UI", 8, "bold"), bg="#7C3AED", fg="#FFF", bd=0, padx=6, pady=2,
                  cursor="hand2", command=self._lie_copy_wardrobe).pack(side=tk.RIGHT, padx=2)

        self.bed_head_lbl = tk.Label(box, text="", font=("Consolas", 8, "bold"), bg="#181926", fg="#38BDF8", justify=tk.LEFT)
        self.bed_head_lbl.pack(anchor=tk.W, pady=2)

        step = tk.Frame(box, bg="#181926"); step.pack(fill=tk.X, pady=2)
        tk.Label(step, text="Paso:", font=("Segoe UI", 8), bg="#181926", fg="#94A3B8").pack(side=tk.LEFT, padx=2)
        for s in (1, 2, 5):
            tk.Radiobutton(step, text=f"{s}px", value=s, variable=self.lie_step_var, bg="#181926", fg="#E2E8F0",
                           selectcolor="#2D3250", font=("Segoe UI", 8)).pack(side=tk.LEFT)
        tk.Checkbutton(step, text="Espejo sincronizado (0↔1, 2↔3)", variable=self.lie_sync_mirror_var, bg="#181926", fg="#94A3B8",
                       selectcolor="#2D3250", font=("Segoe UI", 8)).pack(side=tk.LEFT, padx=6)

        pad = tk.Frame(box, bg="#181926"); pad.pack(pady=2)
        btn = dict(font=("Segoe UI", 9, "bold"), bg="#2D3250", fg="#FFF", bd=0, width=4, pady=2, cursor="hand2")
        diag = dict(font=("Segoe UI", 9, "bold"), bg="#4C1D95", fg="#FFF", bd=0, width=4, pady=2, cursor="hand2")
        # screen-pixel arrows (centre cross) + isometric diagonals (corners, 2:1)
        layout = [
            [("↖", -2, -1, diag), ("▲", 0, -1, btn), ("↗", 2, -1, diag)],
            [("◀", -1, 0, btn), ("·", 0, 0, None), ("▶", 1, 0, btn)],
            [("↙", -2, 1, diag), ("▼", 0, 1, btn), ("↘", 2, 1, diag)],
        ]
        for r, row in enumerate(layout):
            for c, (txt, dx, dy, style) in enumerate(row):
                if style is None:
                    tk.Label(pad, text="", bg="#181926", width=4).grid(row=r, column=c, padx=1, pady=1)
                    continue
                tk.Button(pad, text=txt, command=lambda dx=dx, dy=dy: self._nudge_bed_head(dx, dy), **style).grid(row=r, column=c, padx=1, pady=1)

        actions = tk.Frame(box, bg="#181926"); actions.pack(fill=tk.X, pady=(6, 2))
        tk.Button(actions, text="💾 Guardar en bed_sleep_config.dart", font=("Segoe UI", 9, "bold"), bg="#059669", fg="#FFF", bd=0,
                  pady=4, cursor="hand2", command=self._save_bed_spots).pack(side=tk.LEFT, fill=tk.X, expand=True, padx=(0, 2))
        tk.Button(actions, text="📋 Copiar Dart", font=("Segoe UI", 9, "bold"), bg="#0284C7", fg="#FFF", bd=0, pady=4,
                  cursor="hand2", command=self._copy_bed_dart).pack(side=tk.LEFT, padx=2)
        tk.Button(actions, text="↺ Recargar", font=("Segoe UI", 9, "bold"), bg="#475569", fg="#FFF", bd=0, pady=4,
                  cursor="hand2", command=self._reload_bed_spots).pack(side=tk.LEFT, padx=(2, 0))

    def _lie_look(self):
        """Styles from the calibrator selectors; colours from the wardrobe avatar (or neutral defaults)."""
        look = {
            "body": self.lie_body_var.get(), "eyes": self.lie_eyes_var.get(), "mouth": self.lie_mouth_var.get(),
            "nose": self.lie_nose_var.get(), "hair": self.lie_hair_var.get(),
            "tops": self.lie_top_var.get(), "bottoms": self.lie_bottom_var.get(),
        }
        if self.lie_wardrobe_colors_var.get():
            c = self.config
            def col(key, fallback):
                try:
                    return bsc.hex_rgb(c[key]["color"])
                except Exception:
                    return fallback
            d = bsc.DEFAULT_LOOK
            look.update(skin=col("body", d["skin"]), hair_rgb=col("hair", d["hair_rgb"]), eye_rgb=col("eyes", d["eye_rgb"]),
                        brow_rgb=col("eyebrows", d["brow_rgb"]), top_rgb=col("tops", d["top_rgb"]),
                        bottom_rgb=col("bottoms", d["bottom_rgb"]))
        return look

    def _lie_copy_wardrobe(self):
        """Take the styles of the avatar built in the Armario tab (only those that have lying art)."""
        styles = bsc.available_styles()
        c = self.config
        def pick(key, var, allowed, none_ok=False):
            f = (c.get(key) or {}).get("file")
            if f in allowed or (none_ok and f == "none"):
                var.set(f)
        pick("eyes", self.lie_eyes_var, styles["eyes"])
        pick("mouth", self.lie_mouth_var, styles["mouth"])
        pick("nose", self.lie_nose_var, styles["nose"])
        pick("hair", self.lie_hair_var, styles["hair"], none_ok=True)
        pick("tops", self.lie_top_var, styles["tops"], none_ok=True)
        pick("bottoms", self.lie_bottom_var, styles["bottoms"], none_ok=True)
        acc = (c.get("accessories") or {}).get("file", "none")
        self.lie_acc_var.set(acc if acc == "none" else next(
            (a if has else f"{a} (sin versión acostada)" for a, has in styles["accessories"] if a == acc), "none"))
        body = (c.get("body") or {}).get("file")
        if body in ("male", "female"):
            self.lie_body_var.set(body)
        self.lie_wardrobe_colors_var.set(True)
        self._update_furniture_preview()

    def _current_bed_spot(self):
        return self.bed_spots.get(self.selected_furn_id.get(), {}).get(self.selected_furn_rot)

    def _refresh_bed_label(self):
        spot = self._current_bed_spot()
        if spot is None:
            self.bed_head_lbl.config(text="Este mueble no es una cama configurable\n(bed_sleep_config.dart: single_bed, single_high_bed).")
            return
        self.bed_head_lbl.config(text=(
            f"rot {self.selected_furn_rot}: vista {spot['view'].upper()}  espejo={'sí' if spot['mirror'] else 'no'}\n"
            f"baseHead = ({spot['head'][0]:g}, {spot['head'][1]:g})  (px del sprite, rotación base sin espejo)"))

    def _nudge_bed_head(self, dx, dy):
        spot = self._current_bed_spot()
        if spot is None:
            return
        step = self.lie_step_var.get()
        bdx, bdy = bsc.screen_nudge_to_base(spot, dx * step, dy * step)
        rot = self.selected_furn_rot
        targets = [rot]
        if self.lie_sync_mirror_var.get():
            targets.append(rot ^ 1)   # 0<->1, 2<->3 share the same (unmirrored) baseHead
        for r in targets:
            s = self.bed_spots[self.selected_furn_id.get()].get(r)
            if s is not None:
                s["head"] = [s["head"][0] + bdx, s["head"][1] + bdy]
        self._update_furniture_preview()

    def _save_bed_spots(self):
        try:
            bsc.save_spots(self.bed_spots)
            messagebox.showinfo("Calibrador de Camas", "Guardado en bed_sleep_config.dart.\nEn el juego haz HOT RESTART (R) para verlo.")
        except Exception as e:
            messagebox.showerror("Calibrador de Camas", f"No se pudo guardar: {e}")

    def _copy_bed_dart(self):
        self.root.clipboard_clear()
        self.root.clipboard_append(bsc.dart_map_code(self.bed_spots))
        messagebox.showinfo("Calibrador de Camas", "Bloque _spots copiado al portapapeles.")

    def _reload_bed_spots(self):
        try:
            self.bed_spots = bsc.load_spots()
        except Exception as e:
            messagebox.showerror("Calibrador de Camas", f"No se pudo leer: {e}")
        self._update_furniture_preview()

    def _on_seat_slot_changed(self, event=None):
        self.seat_slot_idx = self.seat_slot_combo.current()
        fid = self.selected_furn_id.get()
        seat_presets = fie.DEFAULT_SEAT_CONFIGS.get(fid, {})
        rot_spots = seat_presets.get(self.selected_furn_rot, [])
        if rot_spots and self.seat_slot_idx < len(rot_spots):
            spot = rot_spots[self.seat_slot_idx]
            self.seat_sub_u.set(spot["sub_cell"][0])
            self.seat_sub_v.set(spot["sub_cell"][1])
            self.seat_voff_x.set(spot["visual_offset"][0])
            self.seat_voff_y.set(spot["visual_offset"][1])
            self.seat_toff_x.set(spot["tap_offset"][0])
            self.seat_toff_y.set(spot["tap_offset"][1])
        self._update_furniture_preview()

    def _on_seat_param_changed(self):
        self._update_furniture_preview()

    def _nudge_seat_visual_offset(self, dx, dy):
        self.seat_voff_x.set(round(self.seat_voff_x.get() + dx, 1))
        self.seat_voff_y.set(round(self.seat_voff_y.get() + dy, 1))
        self._update_furniture_preview()

    def _copy_seat_dart_code(self):
        fid = self.selected_furn_id.get()
        # Construir estructura para todas las 4 rotaciones usando los valores actuales
        seat_dict = {}
        for r in range(4):
            preset_spots = fie.DEFAULT_SEAT_CONFIGS.get(fid, {}).get(r, [])
            if r == self.selected_furn_rot:
                current_spot = {
                    "slot": self.seat_slot_idx,
                    "sub_cell": [int(self.seat_sub_u.get()), int(self.seat_sub_v.get())],
                    "visual_offset": [float(self.seat_voff_x.get()), float(self.seat_voff_y.get())],
                    "tap_offset": [float(self.seat_toff_x.get()), float(self.seat_toff_y.get())]
                }
                if preset_spots and len(preset_spots) > 1:
                    spots = list(preset_spots)
                    spots[min(self.seat_slot_idx, len(spots) - 1)] = current_spot
                    seat_dict[r] = spots
                else:
                    seat_dict[r] = [current_spot]
            else:
                seat_dict[r] = preset_spots if preset_spots else [{
                    "slot": 0, "sub_cell": [0, 0], "visual_offset": [0.0, 0.0], "tap_offset": [0.0, -18.0]
                }]

        dart_code = fie.generate_chair_seat_dart_code(fid, seat_dict)
        self.root.clipboard_clear()
        self.root.clipboard_append(dart_code)
        messagebox.showinfo("Copiado al Portapapeles", f"Configuración Dart para '{fid}' copiada con éxito.\nPégala en frontend/lib/features/lobby/data/chair_seat_config.dart:\n\n{dart_code}")

    def _copy_surface_json_code(self):
        fid = self.selected_furn_id.get().strip()
        fmeta = self.furn_catalog.get(fid, {})
        target_id = fid if fmeta.get("supports_surface") else self.surface_support_id.get().strip()
        h = int(self.surface_height_var.get())
        spots_copy = [dict(s) for s in self.current_surface_spots]
        json_code = fie.generate_surface_spots_json_code(target_id, h, spots_copy)
        self.root.clipboard_clear()
        self.root.clipboard_append(json_code)
        messagebox.showinfo("Copiado al Portapapeles", f"Metadata JSON para '{target_id}' copiada con éxito:\n\n{json_code}")

    def _get_all_catalog_paths(self):
        base_dir = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
        paths = [
            os.path.join(base_dir, "frontend", "assets", "images", "furniture", "furniture_catalog.json"),
            os.path.join(base_dir, "CreateSprites", "assets", "furniture", "furniture_catalog.json"),
            os.path.join(base_dir, "CreateSprites", "assets_32x64", "furniture", "furniture_catalog.json"),
            os.path.join(base_dir, "CreateSprites", "assets_128x256", "furniture", "furniture_catalog.json"),
        ]
        # Sincronizar automáticamente copias compiladas en frontend/build para que Hot Restart (Shift+R)
        # en Flutter (emulador/móvil/desktop) tome los cambios al instante sin necesidad de rebuild completo.
        build_pattern = os.path.join(base_dir, "frontend", "build", "**", "furniture_catalog.json")
        for p in glob.glob(build_pattern, recursive=True):
            p_abs = os.path.abspath(p)
            if p_abs not in paths:
                paths.append(p_abs)
        return paths

    def _save_surface_to_catalog(self):
        fid = self.selected_furn_id.get().strip()
        fmeta = self.furn_catalog.get(fid, {})
        if fmeta.get("supports_surface"):
            target_id = fid
        else:
            target_id = self.surface_support_id.get().strip()
            if not target_id:
                messagebox.showwarning("Atención", "Selecciona primero un mueble soporte.")
                return

        h = int(self.surface_height_var.get())
        spots_copy = [dict(s) for s in self.current_surface_spots]
        first_off = spots_copy[0]["offset"] if spots_copy else [0, 0]

        target_ids = {target_id}
        if target_id.endswith("_sm"):
            target_ids.add(target_id[:-3])
        else:
            target_ids.add(f"{target_id}_sm")

        base_dir = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
        catalog_paths = self._get_all_catalog_paths()

        saved_files = []
        for cat_path in catalog_paths:
            if not os.path.exists(cat_path):
                continue
            try:
                with open(cat_path, "r", encoding="utf-8") as f:
                    cat = json.load(f)

                matched = False
                for tid in target_ids:
                    if tid in cat:
                        matched = True
                        cat[tid]["surface_height"] = h
                        cat[tid]["supports_surface"] = True
                        cat[tid]["surface_offset"] = first_off
                        cat[tid]["surface_spots"] = spots_copy
                        for rot in cat[tid].get("rotations", {}).values():
                            if isinstance(rot, dict):
                                rot["surface_height"] = h
                                rot["supports_surface"] = True
                                rot["surface_offset"] = first_off
                                rot["surface_spots"] = spots_copy

                if matched:
                    with open(cat_path, "w", encoding="utf-8") as f:
                        json.dump(cat, f, indent=2, ensure_ascii=False)
                    saved_files.append(os.path.relpath(cat_path, base_dir))
            except Exception as e:
                print(f"Error guardando superficie en {cat_path}: {e}")

        # Actualizar en memoria en Octo Studio
        for tid in target_ids:
            if tid in self.furn_catalog:
                self.furn_catalog[tid]["surface_height"] = h
                self.furn_catalog[tid]["supports_surface"] = True
                self.furn_catalog[tid]["surface_offset"] = first_off
                self.furn_catalog[tid]["surface_spots"] = spots_copy
                if "rotations" in self.furn_catalog[tid]:
                    for r_val in self.furn_catalog[tid]["rotations"].values():
                        if isinstance(r_val, dict):
                            r_val["surface_height"] = h
                            r_val["supports_surface"] = True
                            r_val["surface_offset"] = first_off
                            r_val["surface_spots"] = spots_copy

        file_list_str = "\n".join([f"  • {f}" for f in saved_files[:6]])
        if len(saved_files) > 6:
            file_list_str += f"\n  ... y {len(saved_files) - 6} archivos más"

        messagebox.showinfo(
            "Guardado en Catálogo",
            f"✅ Configuración de superficie guardada exitosamente para '{target_id}':\n\n"
            f"• Altura (surface_height): {h} px\n"
            f"• Desfase principal (surface_offset): {first_off}\n"
            f"• Lugares configurados: {len(spots_copy)} spots\n\n"
            f"Catálogos y cachés actualizados ({len(saved_files)} archivos):\n{file_list_str}\n\n"
            "Presiona 'Shift + R' (Hot Restart) en Flutter para ver los cambios."
        )

    def _save_offset_to_catalog(self):
        fid = self.selected_furn_id.get().strip()
        if not fid:
            return

        rot = self.selected_furn_rot
        fmeta = self.furn_catalog.get(fid, {})
        rot_data = fmeta.get("rotations", {}).get(rot, {})
        curr_offset = list(self.custom_sprite_offset) if self.custom_sprite_offset is not None else list(rot_data.get("sprite_offset", [-32, -32]))

        target_ids = {fid}
        if fid.endswith("_sm"):
            target_ids.add(fid[:-3])
        else:
            target_ids.add(f"{fid}_sm")

        base_dir = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
        catalog_paths = self._get_all_catalog_paths()

        saved_files = []
        is_surface_or_half = fmeta.get("footprint") in ("surface", "0.5x0.5")
        for cat_path in catalog_paths:
            if not os.path.exists(cat_path):
                continue
            try:
                with open(cat_path, "r", encoding="utf-8") as f:
                    cat = json.load(f)

                matched = False
                for tid in target_ids:
                    if tid in cat:
                        matched = True
                        cat[tid]["sprite_offset"] = curr_offset
                        if "rotations" in cat[tid]:
                            if is_surface_or_half:
                                for r_key in ["0", "1", "2", "3"]:
                                    if r_key in cat[tid]["rotations"]:
                                        cat[tid]["rotations"][r_key]["sprite_offset"] = curr_offset
                            else:
                                rot_key = str(rot)
                                if rot_key in cat[tid]["rotations"]:
                                    cat[tid]["rotations"][rot_key]["sprite_offset"] = curr_offset

                if matched:
                    with open(cat_path, "w", encoding="utf-8") as f:
                        json.dump(cat, f, indent=2, ensure_ascii=False)
                    saved_files.append(os.path.relpath(cat_path, base_dir))
            except Exception as e:
                print(f"Error guardando offset en {cat_path}: {e}")

        # Actualizar en memoria en Octo Studio
        if fid in self.furn_catalog:
            if "rotations" in self.furn_catalog[fid]:
                if is_surface_or_half:
                    for r_val in range(4):
                        if r_val in self.furn_catalog[fid]["rotations"]:
                            self.furn_catalog[fid]["rotations"][r_val]["sprite_offset"] = curr_offset
                else:
                    if rot in self.furn_catalog[fid]["rotations"]:
                        self.furn_catalog[fid]["rotations"][rot]["sprite_offset"] = curr_offset
            self.furn_catalog[fid]["sprite_offset"] = curr_offset

        file_list_str = "\n".join([f"  • {f}" for f in saved_files[:6]])
        if len(saved_files) > 6:
            file_list_str += f"\n  ... y {len(saved_files) - 6} archivos más"

        messagebox.showinfo(
            "Offset Guardado",
            f"✅ sprite_offset guardado para '{fid}' (rot {rot if not is_surface_or_half else 'todas'}):\n\n"
            f"• Offset: dx={curr_offset[0]}, dy={curr_offset[1]}\n\n"
            f"Catálogos y cachés actualizados ({len(saved_files)} archivos):\n{file_list_str}\n\n"
            "Presiona 'Shift + R' (Hot Restart) en Flutter para verlo reflejado."
        )

    def _update_furniture_preview(self):
        if not hasattr(self, "furn_canvas"):
            return

        fid = self.selected_furn_id.get()
        fmeta = self.furn_catalog.get(fid)
        if not fmeta:
            return

        rot_data = fmeta.get("rotations", {}).get(self.selected_furn_rot, {})
        if self.custom_sprite_offset is not None:
            curr_offset = self.custom_sprite_offset
        else:
            cat_off = rot_data.get("sprite_offset", [-32, -32])
            fp = fmeta.get("footprint", "1x1")
            cw, ch = rot_data.get("canvas_size", [128, 176])
            if fp == "0.5x0.5" and (cat_off in ([-32, -44], [-32, -32]) or cat_off[1] == -44):
                curr_offset = [-cw // 4, 8 - (ch // 2)]
            else:
                curr_offset = cat_off
        if hasattr(self, "offset_lbl"):
            self.offset_lbl.config(text=f"Offset: dx={curr_offset[0]}, dy={curr_offset[1]}")

        if hasattr(self, "surf_off_lbl"):
            self.surf_off_lbl.config(text=f"dx={self.surface_off_x.get()}, dy={self.surface_off_y.get()}")

        if hasattr(self, "seat_vo_lbl"):
            self.seat_vo_lbl.config(text=f"visualOffset: dx={self.seat_voff_x.get():.1f}, dy={self.seat_voff_y.get():.1f}")

        current_spot = {
            "slot": self.seat_slot_idx,
            "sub_cell": [int(self.seat_sub_u.get()), int(self.seat_sub_v.get())],
            "visual_offset": [float(self.seat_voff_x.get()), float(self.seat_voff_y.get())],
            "tap_offset": [float(self.seat_toff_x.get()), float(self.seat_toff_y.get())]
        }

        sup_item = None
        if fmeta.get("footprint") == "surface":
            sup_id = self.surface_support_id.get()
            sup_item = self.furn_catalog.get(sup_id)

        if hasattr(self, "bed_head_lbl"):
            self._refresh_bed_label()
        lying_spot = self._current_bed_spot() if self.show_lying_var.get() else None
        if lying_spot is not None:
            try:
                img = bsc.render_preview(fid, self.selected_furn_rot, lying_spot, under=self.lie_under_var.get(),
                                         look=self._lie_look())
                scene_img = img.resize((img.width * self.furn_zoom, img.height * self.furn_zoom), Image.NEAREST)
            except Exception as e:
                print("Vista acostado no disponible:", e)
                lying_spot = None
        if lying_spot is None:
            scene_img = fie.render_furniture_scene(
                furniture_item=fmeta,
                rot=self.selected_furn_rot,
                sprite_offset=tuple(curr_offset),
                show_tiles=self.show_tiles_var.get(),
                show_subcells=self.show_subcells_var.get(),
                show_bounding_box=self.show_bbox_var.get(),
                show_origin=self.show_origin_var.get(),
                show_avatar=self.show_avatar_on_furn_var.get(),
                avatar_config=self.config,
                seat_spot=current_spot,
                surface_support_item=sup_item,
                surface_height=int(self.surface_height_var.get()),
                surface_offset=(int(self.surface_off_x.get()), int(self.surface_off_y.get())),
                surface_spots=self.current_surface_spots,
                active_surface_spot_idx=self.surface_spot_idx,
                show_all_surface_items=self.show_all_surf_items_var.get(),
                show_surface_markers=self.show_surf_markers_var.get(),
                catalog_lookup=self.furn_catalog,
                zoom=self.furn_zoom
            )

        cw = self.furn_canvas.winfo_width() or 460
        ch = self.furn_canvas.winfo_height() or 420

        # Fondo sutil con cuadrícula
        bg_canvas = Image.new("RGBA", (cw, ch), (16, 17, 26, 255))
        d_bg = ImageDraw.Draw(bg_canvas)
        for x in range(0, cw, 16):
            d_bg.line([(x, 0), (x, ch)], fill=(22, 24, 36, 255))
        for y in range(0, ch, 16):
            d_bg.line([(0, y), (cw, y)], fill=(22, 24, 36, 255))

        px = (cw - scene_img.width) // 2
        py = (ch - scene_img.height) // 2
        bg_canvas.paste(scene_img, (px, py), scene_img)

        self.furn_preview_tk = ImageTk.PhotoImage(bg_canvas)
        self.furn_canvas.delete("all")
        self.furn_canvas.create_image(0, 0, image=self.furn_preview_tk, anchor="nw")

    def _on_fps_changed(self, val):
        self.fps = int(val)

    def _set_direction(self, dir_val):
        self.current_direction = dir_val
        self._update_dir_buttons()
        self.update_avatar_preview()

    def _rotate_step(self, step):
        new_d = ((self.current_direction - 1 + step) % 8) + 1
        self._set_direction(new_d)

    def _update_dir_buttons(self):
        for k, btn in self.dir_btns.items():
            btn.config(bg="#2563EB" if k == self.current_direction else "#262A40")
        self.dir_lbl.config(text=f"Dirección Actual: {DIRECTIONS[self.current_direction]['name']}")

    def _on_zoom_changed(self, event=None):
        val = self.zoom_var.get()
        if "1x" in val: self.zoom_level = 1
        elif "2x" in val: self.zoom_level = 2
        elif "3x" in val: self.zoom_level = 3
        elif "4x" in val: self.zoom_level = 4
        self.update_avatar_preview()

    def _randomize_avatar(self):
        for cat in ("head", "eyes", "nose", "mouth", "hair"):
            opts = self.catalog.get(cat, [])
            if opts:
                import random
                self.config[cat]["file"] = random.choice(opts)

        import random
        self.config["hair"]["color"] = random.choice(RETRO_PALETTES["hair"])[1]
        self.config["eyes"]["color"] = random.choice(RETRO_PALETTES["eyes"])[1]
        self.config["body"]["color"] = random.choice(RETRO_PALETTES["skin"])[1]
        self.update_avatar_preview()

    def _reload_catalog(self):
        synced = octo_engine.sync_from_aseprite()
        try:
            import generate_face_walk_frames
            generate_face_walk_frames.generate_walk_frames_for_category("eyes")
            generate_face_walk_frames.generate_walk_frames_for_category("nose")
            generate_face_walk_frames.generate_walk_frames_for_category("mouth")
            generate_face_walk_frames.generate_walk_frames_for_category("head")
            generate_face_walk_frames.generate_walk_frames_for_category("accessories")
            generate_face_walk_frames.generate_walk_frames_for_hair()
        except Exception as e:
            print("Error al regenerar frames de caminata facial:", e)

        clear_cache()
        self.catalog = get_octo_catalog()
        for tab_id in self.notebook.tabs():
            if "Armario" in self.notebook.tab(tab_id, "text"):
                self.notebook.forget(tab_id)
                break
        self._build_tab_wardrobe()
        self.update_avatar_preview()
        if hasattr(self, "_update_furniture_preview"):
            self._update_furniture_preview()
        msg = "Disco recargado y caché limpiado con éxito.\nSe regeneraron las animaciones de caminata a partir de los PNGs estáticos."
        if synced > 0:
            msg += f"\n(Se sincronizaron {synced} archivos más recientes desde Downloads)."
        messagebox.showinfo("Recarga Completa", msg)

    def update_avatar_preview(self):
        if getattr(self, "is_left_panel_minimized", False):
            return

        base_avatar = octo_engine.compose_octo_avatar(
            self.config, direction=self.current_direction, action=self.current_action, frame=self.current_frame
        )

        if self.pending_ai_layer and "frames_by_dir" in self.pending_ai_layer:
            dir_frames = self.pending_ai_layer["frames_by_dir"].get(self.current_direction)
            if dir_frames and isinstance(dir_frames, list) and len(dir_frames) > 0:
                frame_idx = min(self.current_frame, len(dir_frames) - 1)
                pending_frame = dir_frames[frame_idx]
                if pending_frame:
                    base_avatar = Image.alpha_composite(base_avatar, pending_frame)

        cw = self.canvas.winfo_width() or 380
        ch = self.canvas.winfo_height() or 400

        scale = self.zoom_level
        sw, sh = 64 * scale, 128 * scale
        scaled_avatar = base_avatar.resize((sw, sh), resample=Image.Resampling.NEAREST)

        bg_img = Image.new("RGBA", (cw, ch), (13, 14, 21, 255))
        draw = ImageDraw.Draw(bg_img)
        for x in range(0, cw, 16):
            draw.line([(x, 0), (x, ch)], fill=(20, 22, 34, 255))
        for y in range(0, ch, 16):
            draw.line([(0, y), (cw, y)], fill=(20, 22, 34, 255))

        pos_x = (cw - sw) // 2 + getattr(self, "avatar_pan_x", 0)
        pos_y = (ch - sh) // 2 + getattr(self, "avatar_pan_y", 0)
        bg_img.paste(scaled_avatar, (pos_x, pos_y), scaled_avatar)

        self.tk_preview = ImageTk.PhotoImage(bg_img)
        self.canvas.delete("all")
        self.canvas.create_image(0, 0, image=self.tk_preview, anchor="nw")

def main():
    root = tk.Tk()
    app = OctoStudioApp(root)
    root.mainloop()

if __name__ == "__main__":
    main()
