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
        self.root.title("OctoStudio 8D — Avatar Studio & PixelLab Animator")
        self.root.geometry("1180x840")
        self.root.minsize(1080, 720)
        self.root.configure(bg="#12131C")

        # Estado del avatar
        self.config = get_default_config()
        self.current_direction = 1 # 1..8
        self.current_action = "walk" # "idle" o "walk"
        self.current_frame = 0 # 0..3
        self.is_playing = True # Reproduciendo animación
        self.is_auto_rotating = False
        self.fps = 6
        self.zoom_level = 3
        self.anim_loop_id = None

        # Catálogo de assets
        self.catalog = get_octo_catalog()

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
        main_paned = tk.PanedWindow(self.root, orient=tk.HORIZONTAL, bg="#12131C", bd=0, sashwidth=4)
        main_paned.pack(fill=tk.BOTH, expand=True, padx=10, pady=10)

        # =====================================================================
        # PANEL IZQUIERDO: VISOR 8D, BRÚJULA Y ANIMACIÓN
        # =====================================================================
        left_frame = tk.Frame(main_paned, bg="#181926", width=440)
        main_paned.add(left_frame, minsize=410)

        hdr = tk.Frame(left_frame, bg="#181926")
        hdr.pack(fill=tk.X, padx=12, pady=(8, 4))
        tk.Label(hdr, text="🧭 Visor 8 Direcciones (OCTOPLAYER)", font=("Segoe UI", 11, "bold"), bg="#181926", fg="#38BDF8").pack(side=tk.LEFT)

        z_frame = tk.Frame(hdr, bg="#181926")
        z_frame.pack(side=tk.RIGHT)
        tk.Label(z_frame, text="Zoom:", bg="#181926", fg="#94A3B8", font=("Segoe UI", 8)).pack(side=tk.LEFT, padx=2)
        self.zoom_var = tk.StringVar(value="3x (192x384)")
        self.zoom_combo = ttk.Combobox(z_frame, textvariable=self.zoom_var, values=["1x (64x128)", "2x (128x256)", "3x (192x384)", "4x (256x512)"], state="readonly", width=13)
        self.zoom_combo.pack(side=tk.LEFT)
        self.zoom_combo.bind("<<ComboboxSelected>>", self._on_zoom_changed)

        # Canvas del Avatar
        canvas_box = tk.Frame(left_frame, bg="#0D0E15", bd=2, relief="sunken")
        canvas_box.pack(fill=tk.BOTH, expand=True, padx=12, pady=4)
        self.canvas = tk.Canvas(canvas_box, bg="#0D0E15", highlightthickness=0)
        self.canvas.pack(fill=tk.BOTH, expand=True)

        # BRÚJULA DE 8 DIRECCIONES (Sentido horario)
        compass_box = ttk.LabelFrame(left_frame, text=" 🧭 Brújula 8 Direcciones ", padding=6)
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
        anim_box = ttk.LabelFrame(left_frame, text=" 🎬 Animación y Movimiento ", padding=6)
        anim_box.pack(fill=tk.X, padx=12, pady=4)

        mode_row = tk.Frame(anim_box, bg="#181926")
        mode_row.pack(fill=tk.X, pady=(0, 4))

        self.action_var = tk.StringVar(value="walk")
        tk.Radiobutton(mode_row, text="🚶 Caminando (Walk 4-Frames)", value="walk", variable=self.action_var, bg="#181926", fg="#38BDF8", selectcolor="#2D3250", font=("Segoe UI", 8, "bold"), command=self._on_action_changed).pack(side=tk.LEFT, padx=2)
        tk.Radiobutton(mode_row, text="🧍 Detenido (Idle)", value="idle", variable=self.action_var, bg="#181926", fg="#E2E8F0", selectcolor="#2D3250", font=("Segoe UI", 8), command=self._on_action_changed).pack(side=tk.LEFT, padx=6)

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

        act_bar = tk.Frame(left_frame, bg="#181926")
        act_bar.pack(fill=tk.X, padx=12, pady=(4, 8))

        tk.Button(act_bar, text="🎲 Aleatorio", font=("Segoe UI", 8, "bold"), bg="#8B5CF6", fg="#FFF", bd=0, padx=6, pady=4, cursor="hand2", command=self._randomize_avatar).pack(side=tk.LEFT, expand=True, fill=tk.X, padx=1)
        tk.Button(act_bar, text="🔄 Recargar Disco", font=("Segoe UI", 8), bg="#0D9488", fg="#FFF", bd=0, padx=6, pady=4, cursor="hand2", command=self._reload_catalog).pack(side=tk.LEFT, expand=True, fill=tk.X, padx=1)

        # =====================================================================
        # PANEL DERECHO: PESTAÑAS
        # =====================================================================
        right_frame = tk.Frame(main_paned, bg="#181926")
        main_paned.add(right_frame, minsize=620)

        self.notebook = ttk.Notebook(right_frame)
        self.notebook.pack(fill=tk.BOTH, expand=True, padx=6, pady=6)

        self._build_tab_wardrobe()
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
    def _start_animation_loop(self):
        if self.is_playing and self.current_action == "walk":
            self.current_frame = (self.current_frame + 1) % 4
            self.step_lbl.config(text=f"Paso {self.current_frame + 1}/4")

            if self.is_auto_rotating and self.current_frame == 0:
                self.current_direction = (self.current_direction % 8) + 1
                self._update_dir_buttons()

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
        self.current_frame = (self.current_frame - 1) % 4
        self.step_lbl.config(text=f"Paso {self.current_frame + 1}/4")
        self.update_avatar_preview()

    def _next_frame(self):
        self.is_playing = False
        self.play_btn.config(text="▶ Reproducir", bg="#16A34A")
        self.current_frame = (self.current_frame + 1) % 4
        self.step_lbl.config(text=f"Paso {self.current_frame + 1}/4")
        self.update_avatar_preview()

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
        if synced > 0:
            messagebox.showinfo("Sincronización Exitosa", f"Se sincronizaron {synced} archivos y se actualizaron las animaciones de caminata.")

    def update_avatar_preview(self):
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

        pos_x = (cw - sw) // 2
        pos_y = (ch - sh) // 2
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
