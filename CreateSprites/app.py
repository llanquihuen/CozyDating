"""
app.py - Aplicación gráfica de escritorio en Python para crear, visualizar y exportar
Avatares de usuario estilo SNES Chibi en 64x128 PNG.
Incluye soporte para 10 tipos de ojos expresivos, 4 Direcciones, Animación de Caminata en tiempo real,
Exportador a Spritesheet de Videojuegos (4x4) y Exportador a GIF Animado.
"""

import os
import json
import random
import tkinter as tk
from tkinter import ttk, colorchooser, filedialog, messagebox
from PIL import Image, ImageTk, ImageDraw

import color_engine
from color_engine import RETRO_PALETTES, hex_to_rgb, rgb_to_hex
import furniture_engine
import furniture_generator

PRESETS_DIR = "presets"
EXPORTS_DIR = "exports"

class AvatarCreatorApp:
    def __init__(self, root):
        self.root = root
        self.root.title("SNES Chibi Avatar Studio 64x128 - 4 Direcciones & Animación de Caminata")
        self.root.geometry("1120x820")
        self.root.minsize(1020, 720)
        self.root.configure(bg="#13141C")

        os.makedirs(PRESETS_DIR, exist_ok=True)
        os.makedirs(EXPORTS_DIR, exist_ok=True)

        # Configuración del personaje
        self.current_config = {
            "body": {"file": "body_base.png", "color": "#FCD5B5"},
            "face_shape": {"file": "face_oval.png", "color": "#FCD5B5"},
            "face_detail": {"file": "detail_blush.png", "color": "#FF7777"},
            "mouth": {"file": "mouth_smile.png", "color": "#C44242"},
            "nose": {"file": "nose_subtle.png", "color": "#FCD5B5"},
            "eyes": {"file": "eyes_jrpg_classic.png", "color": "#059669"},
            "eyebrows": {"file": "brows_normal.png", "color": "#C85A2A"},
            "hair": {"file": "hair_farm_braids.png", "color": "#C85A2A"},
            "bottoms": {"file": "bottom_farmer_overalls.png", "color": "#2563EB"},
            "shoes": {"file": "shoes_farmer_boots.png", "color": "#78350F"},
            "tops": {"file": "top_flannel_shirt.png", "color": "#DC2626"},
            "accessories": {"file": "acc_straw_hat.png", "color": "#EAB308"}
        }

        # Estado de dirección y animación
        self.current_direction = "down" # 'down', 'up', 'left', 'right', 'all_4'
        self.current_frame = 0 # 0, 1, 2, 3
        self.is_animating = True
        self.fps = 6 # cuadros por segundo
        self.anim_after_id = None
        self.zoom_level = 3
        self.bg_mode = "snes_gradient"
        self.resolution = "64x128"
        self.sync_brows_with_hair = tk.BooleanVar(value=True)

        # Estado de Muebles y Decoración Isométrica
        self.room_items = furniture_engine.get_default_cozy_room_items()
        self.avatar_grid_pos = [3, 2]
        self.selected_room_item_idx = 0
        self.room_preview_tk_img = None

        self.preview_tk_img = None

        self._init_styles()
        self._build_ui()
        self.update_avatar_preview()
        self.update_room_preview()
        self._start_animation_loop()

        # Atajos de teclado para la habitación
        self.root.bind("<Key-r>", self._rotate_selected_room_item)
        self.root.bind("<Key-R>", self._rotate_selected_room_item)

    def _init_styles(self):
        self.style = ttk.Style()
        self.style.theme_use("clam")
        
        self.style.configure(".", background="#181924", foreground="#E2E8F0", font=("Segoe UI", 9))
        self.style.configure("TNotebook", background="#13141C", borderwidth=0)
        self.style.configure("TNotebook.Tab", background="#222436", foreground="#94A3B8", padding=[12, 6], font=("Segoe UI", 9, "bold"))
        self.style.map("TNotebook.Tab", background=[("selected", "#2563EB")], foreground=[("selected", "#FFFFFF")])

        self.style.configure("TFrame", background="#181924")
        self.style.configure("Card.TFrame", background="#1E2030", relief="flat")
        self.style.configure("TLabelframe", background="#181924", foreground="#38BDF8")
        self.style.configure("TLabelframe.Label", background="#181924", foreground="#38BDF8", font=("Segoe UI", 9, "bold"))
        self.style.configure("TLabel", background="#181924", foreground="#F1F5F9")
        self.style.configure("Card.TLabel", background="#1E2030", foreground="#F1F5F9")
        self.style.configure("TCombobox", fieldbackground="#13141C", background="#2D3250", foreground="#FFFFFF", arrowcolor="#38BDF8")
        self.style.map("TCombobox", fieldbackground=[("readonly", "#13141C")], foreground=[("readonly", "#FFFFFF")])

    def _build_ui(self):
        main_paned = tk.PanedWindow(self.root, orient=tk.HORIZONTAL, bg="#13141C", bd=0, sashwidth=4, sashrelief="flat")
        main_paned.pack(fill=tk.BOTH, expand=True, padx=10, pady=10)

        # -------------------------------------------------------------
        # PANEL IZQUIERDO: VISOR, DIRECCIONES Y ANIMACIÓN
        # -------------------------------------------------------------
        left_frame = tk.Frame(main_paned, bg="#181924", width=420)
        main_paned.add(left_frame, minsize=390)

        header = tk.Frame(left_frame, bg="#181924")
        header.pack(fill=tk.X, padx=12, pady=(8, 4))

        title_lbl = tk.Label(header, text="🚶 Sprite Studio", font=("Segoe UI", 12, "bold"), bg="#181924", fg="#38BDF8")
        title_lbl.pack(side=tk.LEFT)

        # Selector de Resolución Emparejada
        res_bar = tk.Frame(header, bg="#181924")
        res_bar.pack(side=tk.RIGHT)

        self.btn_res_64 = tk.Button(res_bar, text="64x128 (Muebles HD)", font=("Segoe UI", 8, "bold"), bg="#2563EB", fg="#FFFFFF", bd=0, padx=8, pady=2, cursor="hand2", command=lambda: self._set_resolution("64x128"))
        self.btn_res_64.pack(side=tk.LEFT, padx=1)

        self.btn_res_32 = tk.Button(res_bar, text="32x64 (Muebles Std)", font=("Segoe UI", 8, "bold"), bg="#2D3250", fg="#94A3B8", bd=0, padx=8, pady=2, cursor="hand2", command=lambda: self._set_resolution("32x64"))
        self.btn_res_32.pack(side=tk.LEFT, padx=1)

        zoom_bar = tk.Frame(left_frame, bg="#181924")
        zoom_bar.pack(fill=tk.X, padx=12, pady=(0, 4))
        
        tk.Label(zoom_bar, text="Zoom:", bg="#181924", fg="#94A3B8", font=("Segoe UI", 8)).pack(side=tk.LEFT, padx=2)
        self.zoom_var = tk.StringVar(value="3x (192x384)")
        self.zoom_combo = ttk.Combobox(zoom_bar, textvariable=self.zoom_var, values=["1x (64x128)", "2x (128x256)", "3x (192x384)", "4x (256x512)"], state="readonly", width=14)
        self.zoom_combo.pack(side=tk.LEFT)
        self.zoom_combo.bind("<<ComboboxSelected>>", self._on_zoom_changed)

        dir_bar = tk.Frame(left_frame, bg="#1E2030", padx=6, pady=4)
        dir_bar.pack(fill=tk.X, padx=12, pady=(0, 4))
        
        tk.Label(dir_bar, text="Dirección:", bg="#1E2030", fg="#38BDF8", font=("Segoe UI", 8, "bold")).pack(side=tk.LEFT, padx=3)
        
        self.dir_buttons = {}
        dirs = [("⬇️ Frente", "down"), ("⬅️ Izq", "left"), ("➡️ Der", "right"), ("⬆️ Espalda", "up"), ("🔄 4 Vistas", "all_4")]
        for text, d_val in dirs:
            btn = tk.Button(
                dir_bar, text=text, font=("Segoe UI", 8),
                bg="#2563EB" if d_val == self.current_direction else "#2D3250",
                fg="#FFFFFF", bd=0, padx=6, pady=2, cursor="hand2",
                command=lambda dv=d_val: self._set_direction(dv)
            )
            btn.pack(side=tk.LEFT, padx=2)
            self.dir_buttons[d_val] = btn

        canvas_container = tk.Frame(left_frame, bg="#0F1017", bd=2, relief="sunken")
        canvas_container.pack(fill=tk.BOTH, expand=True, padx=12, pady=4)

        self.canvas = tk.Canvas(canvas_container, bg="#0F1017", highlightthickness=0)
        self.canvas.pack(fill=tk.BOTH, expand=True)

        anim_bar = tk.Frame(left_frame, bg="#1E2030", padx=6, pady=4)
        anim_bar.pack(fill=tk.X, padx=12, pady=4)

        self.play_btn = tk.Button(anim_bar, text="⏸️ Pausar", font=("Segoe UI", 8, "bold"), bg="#DC2626", fg="#FFFFFF", bd=0, padx=8, pady=3, cursor="hand2", command=self._toggle_animation)
        self.play_btn.pack(side=tk.LEFT, padx=2)

        prev_f_btn = tk.Button(anim_bar, text="⏮️", font=("Segoe UI", 8), bg="#334155", fg="#FFFFFF", bd=0, padx=5, pady=3, cursor="hand2", command=self._prev_frame)
        prev_f_btn.pack(side=tk.LEFT, padx=1)

        self.frame_lbl = tk.Label(anim_bar, text="Paso 1/4", bg="#1E2030", fg="#38BDF8", font=("Segoe UI", 8, "bold"), width=8)
        self.frame_lbl.pack(side=tk.LEFT, padx=1)

        next_f_btn = tk.Button(anim_bar, text="⏭️", font=("Segoe UI", 8), bg="#334155", fg="#FFFFFF", bd=0, padx=5, pady=3, cursor="hand2", command=self._next_frame)
        next_f_btn.pack(side=tk.LEFT, padx=1)

        tk.Label(anim_bar, text="Vel:", bg="#1E2030", fg="#94A3B8", font=("Segoe UI", 8)).pack(side=tk.LEFT, padx=(8, 2))
        self.fps_scale = tk.Scale(anim_bar, from_=2, to=12, orient=tk.HORIZONTAL, bg="#1E2030", fg="#E2E8F0", highlightthickness=0, bd=0, length=80, showvalue=True, command=self._on_fps_changed)
        self.fps_scale.set(self.fps)
        self.fps_scale.pack(side=tk.LEFT, padx=2)

        bg_bar = tk.Frame(left_frame, bg="#181924")
        bg_bar.pack(fill=tk.X, padx=12, pady=2)
        tk.Label(bg_bar, text="Fondo:", bg="#181924", fg="#94A3B8", font=("Segoe UI", 8)).pack(side=tk.LEFT, padx=2)

        bgs = [("SNES", "snes_gradient"), ("Cuadrícula", "checkerboard"), ("Oscuro", "dark"), ("Claro", "light")]
        for label, mode in bgs:
            btn = tk.Button(bg_bar, text=label, font=("Segoe UI", 8), bg="#222436", fg="#E2E8F0", activebackground="#38BDF8", activeforeground="#000", bd=0, padx=5, pady=1,
                            command=lambda m=mode: self._set_bg_mode(m))
            btn.pack(side=tk.LEFT, padx=1)

        action_bar = tk.Frame(left_frame, bg="#181924")
        action_bar.pack(fill=tk.X, padx=12, pady=4)

        rand_btn = tk.Button(action_bar, text="🎲 Aleatorio", font=("Segoe UI", 9, "bold"), bg="#8B5CF6", fg="#FFFFFF", activebackground="#A78BFA", bd=0, padx=8, pady=4, cursor="hand2", command=self.randomize_avatar)
        rand_btn.pack(side=tk.LEFT, expand=True, fill=tk.X, padx=2)

        reload_btn = tk.Button(action_bar, text="🔄 Recargar Disco", font=("Segoe UI", 9), bg="#0D9488", fg="#FFFFFF", activebackground="#14B8A6", bd=0, padx=6, pady=4, cursor="hand2", command=self.reload_from_disk)
        reload_btn.pack(side=tk.LEFT, expand=True, fill=tk.X, padx=2)

        save_btn = tk.Button(action_bar, text="💾 Guardar", font=("Segoe UI", 9), bg="#059669", fg="#FFFFFF", activebackground="#10B981", bd=0, padx=6, pady=4, cursor="hand2", command=self.save_preset_dialog)
        save_btn.pack(side=tk.LEFT, expand=True, fill=tk.X, padx=2)

        load_btn = tk.Button(action_bar, text="📂 Cargar", font=("Segoe UI", 9), bg="#0284C7", fg="#FFFFFF", activebackground="#38BDF8", bd=0, padx=6, pady=4, cursor="hand2", command=self.load_preset_dialog)
        load_btn.pack(side=tk.LEFT, expand=True, fill=tk.X, padx=2)

        export_btn = tk.Button(left_frame, text="🖼️ EXPORTAR (PNG / SPRITESHEET / GIF)", font=("Segoe UI", 10, "bold"), bg="#2563EB", fg="#FFFFFF", activebackground="#3B82F6", bd=0, pady=8, cursor="hand2", command=self.open_export_dialog)
        export_btn.pack(fill=tk.X, padx=12, pady=(2, 10))

        # -------------------------------------------------------------
        # PANEL DERECHO: PESTAÑAS DE EDICIÓN
        # -------------------------------------------------------------
        right_frame = tk.Frame(main_paned, bg="#181924")
        main_paned.add(right_frame, minsize=550)

        self.notebook = ttk.Notebook(right_frame)
        self.notebook.pack(fill=tk.BOTH, expand=True, padx=6, pady=6)

        self._create_tab_face_shape()
        self._create_tab_face()
        self._create_tab_hair()
        self._create_tab_tops()
        self._create_tab_bottoms()
        self._create_tab_shoes()
        self._create_tab_accessories()
        self._create_tab_furniture()

    # -------------------------------------------------------------
    # BUCLE DE ANIMACIÓN
    # -------------------------------------------------------------
    def _start_animation_loop(self):
        if self.is_animating:
            self.current_frame = (self.current_frame + 1) % 4
            self.frame_lbl.config(text=f"Paso {self.current_frame + 1}/4")
            self.update_avatar_preview()
            
        delay_ms = int(1000 / max(1, self.fps))
        self.anim_after_id = self.root.after(delay_ms, self._start_animation_loop)

    def _toggle_animation(self):
        self.is_animating = not self.is_animating
        if self.is_animating:
            self.play_btn.config(text="⏸️ Pausar", bg="#DC2626")
        else:
            self.play_btn.config(text="▶️ Caminar", bg="#16A34A")

    def _prev_frame(self):
        self.is_animating = False
        self.play_btn.config(text="▶️ Caminar", bg="#16A34A")
        self.current_frame = (self.current_frame - 1) % 4
        self.frame_lbl.config(text=f"Paso {self.current_frame + 1}/4")
        self.update_avatar_preview()

    def _next_frame(self):
        self.is_animating = False
        self.play_btn.config(text="▶️ Caminar", bg="#16A34A")
        self.current_frame = (self.current_frame + 1) % 4
        self.frame_lbl.config(text=f"Paso {self.current_frame + 1}/4")
        self.update_avatar_preview()

    def _on_fps_changed(self, val):
        self.fps = int(val)

    def _set_direction(self, dir_val):
        self.current_direction = dir_val
        for k, btn in self.dir_buttons.items():
            btn.config(bg="#2563EB" if k == dir_val else "#2D3250")
        self.update_avatar_preview()

    # -------------------------------------------------------------
    # PESTAÑAS DE CONFIGURACIÓN
    # -------------------------------------------------------------
    def _create_tab_face_shape(self):
        tab = ttk.Frame(self.notebook, padding=10)
        self.notebook.add(tab, text="👤 Cara & Piel")

        sec1 = ttk.LabelFrame(tab, text=" Forma de la Cara / Mandíbula ", padding=10)
        sec1.pack(fill=tk.X, pady=(0, 10))

        self.face_shape_var = tk.StringVar(value=self.current_config["face_shape"]["file"])
        shapes = [
            ("Cara Ovalada Clásica (Curvas suaves)", "face_oval.png"),
            ("Cara Redonda / Tierna (Stardew Valley)", "face_round.png"),
            ("Cara Afilada en V (Héroe / Bishonen JRPG)", "face_sharp_v.png"),
            ("Mandíbula Marcada / Firme (Guerrero)", "face_square_jaw.png"),
            ("Forma de Corazón / Pómulos Altos", "face_heart.png"),
        ]
        for text, val in shapes:
            rb = tk.Radiobutton(sec1, text=text, value=val, variable=self.face_shape_var, bg="#181924", fg="#E2E8F0", selectcolor="#2D3250", activebackground="#181924", activeforeground="#38BDF8", font=("Segoe UI", 9), command=self._on_face_shape_changed)
            rb.pack(anchor=tk.W, pady=2)

        self._create_color_picker_section(tab, "Tono de Piel Unisex", "body", RETRO_PALETTES["skin"], "skin")

    def _create_tab_face(self):
        tab = ttk.Frame(self.notebook, padding=10)
        self.notebook.add(tab, text="👀 Ojos & Expresión")

        canvas = tk.Canvas(tab, bg="#181924", highlightthickness=0)
        scrollbar = ttk.Scrollbar(tab, orient="vertical", command=canvas.yview)
        scrollable_frame = ttk.Frame(canvas)
        scrollable_frame.bind("<Configure>", lambda e: canvas.configure(scrollregion=canvas.bbox("all")))
        canvas.create_window((0, 0), window=scrollable_frame, anchor="nw")
        canvas.configure(yscrollcommand=scrollbar.set)
        canvas.pack(side="left", fill="both", expand=True)
        scrollbar.pack(side="right", fill="y")

        # 1. Colección de Ojos (10 Tipos Expresivos)
        eyes_sec = ttk.LabelFrame(scrollable_frame, text=" Tipos de Ojos (10 Estilos SNES / Anime / JRPG) ", padding=10)
        eyes_sec.pack(fill=tk.X, pady=(0, 8))

        self.eyes_var = tk.StringVar(value=self.current_config["eyes"]["file"])
        eyes_opts = [
            ("✨ Ojos Anime Shoujo Brillantes (Grandes destellos)", "eyes_shoujo_sparkle.png"),
            ("🌾 Ojos Grandes & Tiernos (Stardew Valley)", "eyes_stardew_cute.png"),
            ("⚔️ Ojos JRPG Clásicos con Brillo (Chrono / Octopath)", "eyes_jrpg_classic.png"),
            ("🛡️ Ojos Determinados / Mirada Firme de Héroe", "eyes_adventurer_serious.png"),
            ("🍃 Ojos Somnolientos / Calmados & Serena", "eyes_sleepy_calm.png"),
            ("😸 Ojos Rasgados Pícaros / Kitsune / Gato", "eyes_cateye_sly.png"),
            ("🔮 Ojos Místicos / Resplandor de Hechicero", "eyes_mystic_glow.png"),
            ("😊 Ojos Felices Cerrados en Arco (^ ^)", "eyes_happy_closed.png"),
            ("⚫ Ojos Redondos Simplificados Chibi (Mother / Dot)", "eyes_dot_chibi.png"),
            ("😉 Guiño Pícaro (> ^)", "eyes_wink.png"),
        ]
        for text, val in eyes_opts:
            rb = tk.Radiobutton(eyes_sec, text=text, value=val, variable=self.eyes_var, bg="#181924", fg="#E2E8F0", selectcolor="#2D3250", activebackground="#181924", activeforeground="#38BDF8", font=("Segoe UI", 9), command=lambda: self._on_item_changed("eyes", self.eyes_var.get()))
            rb.pack(anchor=tk.W, pady=2)

        self._create_color_picker_section(eyes_sec, "Color del Iris", "eyes", RETRO_PALETTES["eyes"], "eyes")

        # 2. Cejas
        brows_sec = ttk.LabelFrame(scrollable_frame, text=" Cejas ", padding=10)
        brows_sec.pack(fill=tk.X, pady=(0, 8))

        self.brows_var = tk.StringVar(value=self.current_config["eyebrows"]["file"])
        brows_opts = [
            ("Normales Suaves", "brows_normal.png"),
            ("Gruesas y Expresivas", "brows_thick.png"),
            ("Serias de Guerrero", "brows_serious.png"),
            ("Arqueadas Curiosas", "brows_arched.png"),
        ]
        for text, val in brows_opts:
            rb = tk.Radiobutton(brows_sec, text=text, value=val, variable=self.brows_var, bg="#181924", fg="#E2E8F0", selectcolor="#2D3250", activebackground="#181924", activeforeground="#38BDF8", font=("Segoe UI", 9), command=lambda: self._on_item_changed("eyebrows", self.brows_var.get()))
            rb.pack(anchor=tk.W, pady=1)

        sync_cb = tk.Checkbutton(brows_sec, text="Sincronizar color de cejas con el cabello", variable=self.sync_brows_with_hair, bg="#181924", fg="#38BDF8", selectcolor="#2D3250", activebackground="#181924", activeforeground="#38BDF8", font=("Segoe UI", 9, "bold"))
        sync_cb.pack(anchor=tk.W, pady=(4, 0))

        # 3. Nariz
        nose_sec = ttk.LabelFrame(scrollable_frame, text=" Nariz ", padding=10)
        nose_sec.pack(fill=tk.X, pady=(0, 8))
        self.nose_var = tk.StringVar(value=self.current_config["nose"]["file"])
        noses = [
            ("Sutil 1-Pixel (Stardew / SNES)", "nose_subtle.png"),
            ("Perfilada / Puntiaguda", "nose_pointed.png"),
            ("Botón Redonda", "nose_button.png"),
        ]
        for text, val in noses:
            rb = tk.Radiobutton(nose_sec, text=text, value=val, variable=self.nose_var, bg="#181924", fg="#E2E8F0", selectcolor="#2D3250", activebackground="#181924", activeforeground="#38BDF8", font=("Segoe UI", 9), command=lambda: self._on_item_changed("nose", self.nose_var.get()))
            rb.pack(anchor=tk.W, pady=1)

        # 4. Boca
        mouth_sec = ttk.LabelFrame(scrollable_frame, text=" Boca & Expresión ", padding=10)
        mouth_sec.pack(fill=tk.X, pady=(0, 8))
        self.mouth_var = tk.StringVar(value=self.current_config["mouth"]["file"])
        mouths = [
            ("Sonrisa Dulce Campestre", "mouth_smile.png"),
            ("Neutra Serena", "mouth_neutral.png"),
            ("Sonrisa Abierta Alegre", "mouth_open_smile.png"),
            ("Pícara / Smirk", "mouth_smirk.png"),
            ("Labial Elegante", "mouth_lipstick.png"),
        ]
        for text, val in mouths:
            rb = tk.Radiobutton(mouth_sec, text=text, value=val, variable=self.mouth_var, bg="#181924", fg="#E2E8F0", selectcolor="#2D3250", activebackground="#181924", activeforeground="#38BDF8", font=("Segoe UI", 9), command=lambda: self._on_item_changed("mouth", self.mouth_var.get()))
            rb.pack(anchor=tk.W, pady=1)

        # 5. Detalles Faciales
        detail_sec = ttk.LabelFrame(scrollable_frame, text=" Detalles Faciales ", padding=10)
        detail_sec.pack(fill=tk.X, pady=(0, 8))
        self.detail_var = tk.StringVar(value=self.current_config["face_detail"]["file"])
        details = [
            ("Ninguno", "detail_none.png"),
            ("Rubor Suave (Stardew Blush)", "detail_blush.png"),
            ("Pecas Campestres", "detail_freckles.png"),
            ("Cicatriz de Batalla", "detail_scar.png"),
        ]
        for text, val in details:
            rb = tk.Radiobutton(detail_sec, text=text, value=val, variable=self.detail_var, bg="#181924", fg="#E2E8F0", selectcolor="#2D3250", activebackground="#181924", activeforeground="#38BDF8", font=("Segoe UI", 9), command=lambda: self._on_item_changed("face_detail", self.detail_var.get()))
            rb.pack(anchor=tk.W, pady=1)

    def _create_tab_hair(self):
        tab = ttk.Frame(self.notebook, padding=10)
        self.notebook.add(tab, text="✂️ Peinado")

        sec1 = ttk.LabelFrame(tab, text=" Estilo de Cabello ", padding=10)
        sec1.pack(fill=tk.X, pady=(0, 10))

        self.hair_var = tk.StringVar(value=self.current_config["hair"]["file"])
        hairs = [
            ("Trenzas Rústicas Campestres (Leah Stardew)", "hair_farm_braids.png"),
            ("Corto Puntiagudo de Aventurero (Chrono/Octopath)", "hair_adventurer_spiky.png"),
            ("Melena Larga y Ondulante", "hair_long_flowing.png"),
            ("Corte Bob con Flequillo", "hair_bob_bangs.png"),
            ("Rizos y Ondas Campestres", "hair_curly_locks.png"),
            ("Coleta Alta de Trabajo / Guerrero", "hair_high_ponytail.png"),
            ("Coletas Dobles (Twin Tails)", "hair_twintails.png"),
            ("Desordenado Trotamundos", "hair_messy_wanderer.png"),
            ("Sin Cabello / Rapado", "hair_none.png"),
        ]
        for text, val in hairs:
            rb = tk.Radiobutton(sec1, text=text, value=val, variable=self.hair_var, bg="#181924", fg="#E2E8F0", selectcolor="#2D3250", activebackground="#181924", activeforeground="#38BDF8", font=("Segoe UI", 9), command=self._on_hair_style_changed)
            rb.pack(anchor=tk.W, pady=1)

        self._create_color_picker_section(tab, "Color de Cabello", "hair", RETRO_PALETTES["hair"], "hair")

    def _create_tab_tops(self):
        tab = ttk.Frame(self.notebook, padding=10)
        self.notebook.add(tab, text="👕 Ropa Superior")

        sec1 = ttk.LabelFrame(tab, text=" Prenda Superior ", padding=10)
        sec1.pack(fill=tk.X, pady=(0, 10))

        self.tops_var = tk.StringVar(value=self.current_config["tops"]["file"])
        tops = [
            ("Camisa de Franela Campestre (Stardew Classic)", "top_flannel_shirt.png"),
            ("Pechera de Peto / Overalls con Tirantes", "top_overalls_bib.png"),
            ("Túnica de Viajero con Cinturón y Hebilla", "top_traveler_tunic.png"),
            ("Abrigo Largo de Aventurero con Cuello de Piel", "top_adventurer_coat.png"),
            ("Polera Cómoda de Algodón", "top_tshirt.png"),
            ("Sudadera Urbana con Capucha / Hoodie", "top_hoodie.png"),
            ("Crop Top Deportivo", "top_crop_top.png"),
            ("Top Bikini / Ropa Interior", "top_bikini.png"),
            ("Sin Prenda Superior", "top_none.png"),
        ]
        for text, val in tops:
            rb = tk.Radiobutton(sec1, text=text, value=val, variable=self.tops_var, bg="#181924", fg="#E2E8F0", selectcolor="#2D3250", activebackground="#181924", activeforeground="#38BDF8", font=("Segoe UI", 9), command=lambda: self._on_item_changed("tops", self.tops_var.get()))
            rb.pack(anchor=tk.W, pady=1)

        self._create_color_picker_section(tab, "Color de Prenda Superior", "tops", RETRO_PALETTES["clothing"], "clothing")

    def _create_tab_bottoms(self):
        tab = ttk.Frame(self.notebook, padding=10)
        self.notebook.add(tab, text="👖 Ropa Inferior")

        sec1 = ttk.LabelFrame(tab, text=" Prenda Inferior ", padding=10)
        sec1.pack(fill=tk.X, pady=(0, 10))

        self.bottoms_var = tk.StringVar(value=self.current_config["bottoms"]["file"])
        bottoms = [
            ("Peto de Granjero con Parche (Stardew Overalls)", "bottom_farmer_overalls.png"),
            ("Pantalones de Aventurero / Cuero (Octopath)", "bottom_adventurer_pants.png"),
            ("Falda Campesina Rústica con Vuelo", "bottom_rustic_skirt.png"),
            ("Falda Plisada Corta", "bottom_skirt_pleated.png"),
            ("Shorts de Explorador", "bottom_shorts.png"),
            ("Bóxer / Ropa Interior", "bottom_underwear.png"),
            ("Bikini Bottom / Traje de Baño", "bottom_bikini.png"),
            ("Sin Prenda Inferior", "bottom_none.png"),
        ]
        for text, val in bottoms:
            rb = tk.Radiobutton(sec1, text=text, value=val, variable=self.bottoms_var, bg="#181924", fg="#E2E8F0", selectcolor="#2D3250", activebackground="#181924", activeforeground="#38BDF8", font=("Segoe UI", 9), command=lambda: self._on_item_changed("bottoms", self.bottoms_var.get()))
            rb.pack(anchor=tk.W, pady=1)

        self._create_color_picker_section(tab, "Color de Prenda Inferior", "bottoms", RETRO_PALETTES["clothing"], "clothing")

    def _create_tab_shoes(self):
        tab = ttk.Frame(self.notebook, padding=10)
        self.notebook.add(tab, text="👢 Calzado")

        sec1 = ttk.LabelFrame(tab, text=" Tipo de Calzado ", padding=10)
        sec1.pack(fill=tk.X, pady=(0, 10))

        self.shoes_var = tk.StringVar(value=self.current_config["shoes"]["file"])
        shoes = [
            ("Botas de Explorador con Vuelta y Hebilla", "shoes_adventurer_boots.png"),
            ("Botas de Trabajo de Granjero (Stardew)", "shoes_farmer_boots.png"),
            ("Zapatillas Deportivas con Suela Blanca", "shoes_sneakers.png"),
            ("Sandalias de Cuero de Verano", "shoes_sandals.png"),
            ("Descalzo", "shoes_none.png"),
        ]
        for text, val in shoes:
            rb = tk.Radiobutton(sec1, text=text, value=val, variable=self.shoes_var, bg="#181924", fg="#E2E8F0", selectcolor="#2D3250", activebackground="#181924", activeforeground="#38BDF8", font=("Segoe UI", 9), command=lambda: self._on_item_changed("shoes", self.shoes_var.get()))
            rb.pack(anchor=tk.W, pady=1)

        self._create_color_picker_section(tab, "Color de Calzado", "shoes", RETRO_PALETTES["clothing"], "clothing")

    def _create_tab_accessories(self):
        tab = ttk.Frame(self.notebook, padding=10)
        self.notebook.add(tab, text="👒 Accesorios")

        sec1 = ttk.LabelFrame(tab, text=" Accesorio Temático ", padding=10)
        sec1.pack(fill=tk.X, pady=(0, 10))

        self.acc_var = tk.StringVar(value=self.current_config["accessories"]["file"])
        accs = [
            ("Sombrero de Paja de Granjero con Cinta (Stardew)", "acc_straw_hat.png"),
            ("Capucha & Capa Corta de Trotamundos", "acc_traveler_hood.png"),
            ("Flor Silvestre en el Cabello", "acc_hair_flower.png"),
            ("Gafas Redondas de Erudito / Mago", "acc_scholar_glasses.png"),
            ("Pañuelo / Bandana al Cuello", "acc_neck_bandana.png"),
            ("Morral / Bolso de Viajero Cruzado", "acc_satchel_bag.png"),
            ("Audífonos de Diadema Modernos", "acc_headphones.png"),
            ("Gafas de Sol Cool", "acc_sunglasses_cool.png"),
            ("Sin Accesorio", "acc_none.png"),
        ]
        for text, val in accs:
            rb = tk.Radiobutton(sec1, text=text, value=val, variable=self.acc_var, bg="#181924", fg="#E2E8F0", selectcolor="#2D3250", activebackground="#181924", activeforeground="#38BDF8", font=("Segoe UI", 9), command=lambda: self._on_item_changed("accessories", self.acc_var.get()))
            rb.pack(anchor=tk.W, pady=1)

        self._create_color_picker_section(tab, "Color de Accesorio", "accessories", RETRO_PALETTES["clothing"], "clothing")

    # -------------------------------------------------------------
    # SECCIÓN REUTILIZABLE DE SELECTOR DE COLOR & PALETAS RETRO
    # -------------------------------------------------------------
    def _create_color_picker_section(self, parent, title, category, swatch_palette, cat_type):
        frame = ttk.LabelFrame(parent, text=f" {title} ", padding=10)
        frame.pack(fill=tk.X, pady=(4, 0))

        top_row = tk.Frame(frame, bg="#181924")
        top_row.pack(fill=tk.X, pady=(0, 8))

        curr_color = self.current_config[category]["color"]
        color_preview = tk.Canvas(top_row, width=32, height=24, bg=curr_color, highlightthickness=1, highlightbackground="#475569")
        color_preview.pack(side=tk.LEFT, padx=(0, 8))

        hex_lbl = tk.Label(top_row, text=curr_color, font=("Consolas", 10, "bold"), bg="#181924", fg="#38BDF8")
        hex_lbl.pack(side=tk.LEFT, padx=(0, 10))

        def pick_custom_color():
            color_data = colorchooser.askcolor(color=self.current_config[category]["color"], title=f"Elegir color para {title}")
            if color_data and color_data[1]:
                new_hex = color_data[1].upper()
                self._apply_category_color(category, new_hex, color_preview, hex_lbl)

        pick_btn = tk.Button(top_row, text="🎨 Selector RGB...", font=("Segoe UI", 9), bg="#3B82F6", fg="#FFFFFF", activebackground="#60A5FA", bd=0, padx=8, pady=3, cursor="hand2", command=pick_custom_color)
        pick_btn.pack(side=tk.RIGHT)

        swatches_frame = tk.Frame(frame, bg="#181924")
        swatches_frame.pack(fill=tk.X)

        cols = 6
        for idx, (name, hex_code) in enumerate(swatch_palette):
            r = idx // cols
            c = idx % cols
            s_btn = tk.Button(
                swatches_frame,
                bg=hex_code,
                activebackground=hex_code,
                width=3,
                height=1,
                bd=1,
                relief="ridge",
                cursor="hand2",
                command=lambda h=hex_code: self._apply_category_color(category, h, color_preview, hex_lbl)
            )
            s_btn.grid(row=r, column=c, padx=3, pady=3)

    def _create_tab_furniture(self):
        tab = ttk.Frame(self.notebook, padding=10)
        self.notebook.add(tab, text="🛋️ Muebles & Habitación")

        paned = tk.PanedWindow(tab, orient=tk.HORIZONTAL, bg="#181924", bd=0, sashwidth=4)
        paned.pack(fill=tk.BOTH, expand=True)

        # -------------------------------------------------------------
        # IZQUIERDA: CANVAS INTERACTIVO DE LA HABITACIÓN
        # -------------------------------------------------------------
        room_left = tk.Frame(paned, bg="#181924")
        paned.add(room_left, minsize=420)

        r_hdr = tk.Frame(room_left, bg="#181924")
        r_hdr.pack(fill=tk.X, pady=(0, 4))
        tk.Label(r_hdr, text="🏠 Habitación Isométrica Interactiva", font=("Segoe UI", 10, "bold"), bg="#181924", fg="#38BDF8").pack(side=tk.LEFT)

        canvas_cont = tk.Frame(room_left, bg="#0F1017", bd=2, relief="sunken")
        canvas_cont.pack(fill=tk.BOTH, expand=True, pady=4)

        self.room_canvas = tk.Canvas(canvas_cont, bg="#0F1017", highlightthickness=0)
        self.room_canvas.pack(fill=tk.BOTH, expand=True)
        self.room_canvas.bind("<Button-1>", self._on_room_canvas_click)

        # Panel de Manipulación del Elemento Seleccionado
        move_box = ttk.LabelFrame(room_left, text=" 🕹️ Mover & Rotar Elemento Seleccionado ", padding=6)
        move_box.pack(fill=tk.X, pady=4)

        m_top = tk.Frame(move_box, bg="#181924")
        m_top.pack(fill=tk.X)

        self.selected_item_lbl = tk.Label(m_top, text="Selección: Cama King Matrimonial (gx=0, gy=2, 0°)", font=("Segoe UI", 9, "bold"), bg="#181924", fg="#38BDF8")
        self.selected_item_lbl.pack(side=tk.LEFT)

        rot_btn = tk.Button(m_top, text="🔄 Rotar 90° (R)", font=("Segoe UI", 9, "bold"), bg="#0284C7", fg="#FFF", bd=0, padx=8, pady=2, cursor="hand2", command=self._rotate_selected_room_item)
        rot_btn.pack(side=tk.RIGHT)

        m_ctrls = tk.Frame(move_box, bg="#181924")
        m_ctrls.pack(fill=tk.X, pady=4)

        tk.Label(m_ctrls, text="Baldosa:", font=("Segoe UI", 8), bg="#181924", fg="#94A3B8").pack(side=tk.LEFT, padx=2)
        tk.Button(m_ctrls, text="⬅️ X-", font=("Segoe UI", 8), bg="#334155", fg="#FFF", bd=0, padx=5, pady=2, command=lambda: self._nudge_selected_tile(-1, 0)).pack(side=tk.LEFT, padx=1)
        tk.Button(m_ctrls, text="➡️ X+", font=("Segoe UI", 8), bg="#334155", fg="#FFF", bd=0, padx=5, pady=2, command=lambda: self._nudge_selected_tile(1, 0)).pack(side=tk.LEFT, padx=1)
        tk.Button(m_ctrls, text="⬆️ Y-", font=("Segoe UI", 8), bg="#334155", fg="#FFF", bd=0, padx=5, pady=2, command=lambda: self._nudge_selected_tile(0, -1)).pack(side=tk.LEFT, padx=1)
        tk.Button(m_ctrls, text="⬇️ Y+", font=("Segoe UI", 8), bg="#334155", fg="#FFF", bd=0, padx=5, pady=2, command=lambda: self._nudge_selected_tile(0, 1)).pack(side=tk.LEFT, padx=1)

        tk.Label(m_ctrls, text="Ajuste fino (px):", font=("Segoe UI", 8), bg="#181924", fg="#94A3B8").pack(side=tk.LEFT, padx=(8, 2))
        tk.Button(m_ctrls, text="◀ -2x", font=("Segoe UI", 8), bg="#2D3250", fg="#FFF", bd=0, padx=4, pady=2, command=lambda: self._nudge_selected_pixel(-2, 0)).pack(side=tk.LEFT, padx=1)
        tk.Button(m_ctrls, text="▶ +2x", font=("Segoe UI", 8), bg="#2D3250", fg="#FFF", bd=0, padx=4, pady=2, command=lambda: self._nudge_selected_pixel(2, 0)).pack(side=tk.LEFT, padx=1)
        tk.Button(m_ctrls, text="▲ -2y", font=("Segoe UI", 8), bg="#2D3250", fg="#FFF", bd=0, padx=4, pady=2, command=lambda: self._nudge_selected_pixel(0, -2)).pack(side=tk.LEFT, padx=1)
        tk.Button(m_ctrls, text="▼ +2y", font=("Segoe UI", 8), bg="#2D3250", fg="#FFF", bd=0, padx=4, pady=2, command=lambda: self._nudge_selected_pixel(0, 2)).pack(side=tk.LEFT, padx=1)

        tk.Button(m_ctrls, text="🗑️ Borrar", font=("Segoe UI", 8, "bold"), bg="#DC2626", fg="#FFF", bd=0, padx=6, pady=2, command=self._delete_selected_room_item).pack(side=tk.RIGHT, padx=2)

        # -------------------------------------------------------------
        # DERECHA: CATÁLOGO TEMÁTICO (COCINA, DORMITORIO, BAÑO, PATIO)
        # -------------------------------------------------------------
        room_right = tk.Frame(paned, bg="#181924", padx=6)
        paned.add(room_right, minsize=350)

        # Filtros de Categoría / Zona
        filter_bar = tk.Frame(room_right, bg="#181924")
        filter_bar.pack(fill=tk.X, pady=(0, 4))

        self.zone_filter_var = tk.StringVar(value="all")
        zones = [("🌟 Todos", "all"), ("📦 Guías", "guide"), ("🍳 Cocina", "kitchen"), ("🛏️ Dorm.", "bedroom"), ("🚿 Baño", "bathroom"), ("🌳 Patio", "patio"), ("🖼️ Pared", "wall"), ("🍵 Mesa", "surface")]
        for text, z_val in zones:
            btn = tk.Button(
                filter_bar, text=text, font=("Segoe UI", 8),
                bg="#2563EB" if z_val == "all" else "#222436",
                fg="#FFFFFF", bd=0, padx=5, pady=2, cursor="hand2",
                command=lambda zv=z_val: self._set_zone_filter(zv)
            )
            btn.pack(side=tk.LEFT, padx=1)

        cat_sec = ttk.LabelFrame(room_right, text=" Catálogo de Muebles ", padding=6)
        cat_sec.pack(fill=tk.BOTH, expand=True, pady=(0, 4))

        self.furniture_catalog = furniture_engine.load_furniture_catalog(self.resolution)
        self.selected_furniture_id = tk.StringVar(value="wooden_chair")

        self.furn_canvas = tk.Canvas(cat_sec, bg="#181924", highlightthickness=0)
        self.furn_scroll = ttk.Scrollbar(cat_sec, orient="vertical", command=self.furn_canvas.yview)
        self.furn_frame = ttk.Frame(self.furn_canvas)
        self.furn_frame.bind("<Configure>", lambda e: self.furn_canvas.configure(scrollregion=self.furn_canvas.bbox("all")))
        self.furn_canvas.create_window((0, 0), window=self.furn_frame, anchor="nw")
        self.furn_canvas.configure(yscrollcommand=self.furn_scroll.set)
        self.furn_canvas.pack(side="left", fill="both", expand=True)
        self.furn_scroll.pack(side="right", fill="y")

        self._populate_furniture_list()

        # Ficha técnica
        self.meta_card = ttk.LabelFrame(room_right, text=" Ficha Técnica ", padding=6)
        self.meta_card.pack(fill=tk.X, pady=2)

        self.meta_lbl = tk.Label(self.meta_card, text="", justify=tk.LEFT, font=("Segoe UI", 8), bg="#181924", fg="#94A3B8")
        self.meta_lbl.pack(anchor=tk.W)
        self._on_furniture_selected()

        # Controles de colocación
        place_box = ttk.LabelFrame(room_right, text=" Añadir Mueble a la Habitación ", padding=6)
        place_box.pack(fill=tk.X, pady=2)

        p_grid = tk.Frame(place_box, bg="#181924")
        p_grid.pack(fill=tk.X, pady=1)

        tk.Label(p_grid, text="Baldosa (gx, gy):", font=("Segoe UI", 8), bg="#181924", fg="#F1F5F9").pack(side=tk.LEFT)
        self.place_gx_spin = tk.Spinbox(p_grid, from_=0, to=5, width=3, font=("Segoe UI", 9))
        self.place_gx_spin.delete(0, "end"); self.place_gx_spin.insert(0, "2")
        self.place_gx_spin.pack(side=tk.LEFT, padx=2)

        self.place_gy_spin = tk.Spinbox(p_grid, from_=0, to=5, width=3, font=("Segoe UI", 9))
        self.place_gy_spin.delete(0, "end"); self.place_gy_spin.insert(0, "2")
        self.place_gy_spin.pack(side=tk.LEFT, padx=2)

        tk.Label(p_grid, text="Rotación:", font=("Segoe UI", 8), bg="#181924", fg="#F1F5F9").pack(side=tk.LEFT, padx=(6, 2))
        self.place_rot_combo = ttk.Combobox(p_grid, values=["0° (SE)", "90° (SW)", "180° (NW)", "270° (NE)"], state="readonly", width=9)
        self.place_rot_combo.current(0)
        self.place_rot_combo.pack(side=tk.LEFT, padx=2)

        add_btn = tk.Button(place_box, text="➕ Colocar Mueble", font=("Segoe UI", 9, "bold"), bg="#16A34A", fg="#FFFFFF", bd=0, padx=6, pady=3, cursor="hand2", command=self._add_furniture_to_room)
        add_btn.pack(fill=tk.X, pady=2)

        btn_row = tk.Frame(place_box, bg="#181924")
        btn_row.pack(fill=tk.X, pady=1)

        tk.Button(btn_row, text="🔄 Habitación Modelo", font=("Segoe UI", 8), bg="#2563EB", fg="#FFFFFF", bd=0, padx=4, pady=2, cursor="hand2", command=self._reset_room_to_default).pack(side=tk.LEFT, expand=True, fill=tk.X, padx=1)
        tk.Button(btn_row, text="🧹 Vaciar Todo", font=("Segoe UI", 8), bg="#475569", fg="#FFFFFF", bd=0, padx=4, pady=2, cursor="hand2", command=self._clear_all_furniture).pack(side=tk.LEFT, expand=True, fill=tk.X, padx=1)

        exp_room_btn = tk.Button(room_right, text="🖼️ Exportar Habitación Completa (PNG)", font=("Segoe UI", 9, "bold"), bg="#8B5CF6", fg="#FFFFFF", bd=0, pady=5, cursor="hand2", command=self._export_room_image)
        exp_room_btn.pack(fill=tk.X, pady=(4, 2))

    def _set_zone_filter(self, zone_val):
        self.zone_filter_var.set(zone_val)
        self._populate_furniture_list()

    def _populate_furniture_list(self):
        for widget in self.furn_frame.winfo_children():
            widget.destroy()

        zone = self.zone_filter_var.get()
        for f_id in furniture_generator.FURNITURE_LIST:
            meta = self.furniture_catalog.get(f_id, {})
            f_zone = meta.get("zone", "living")
            foot = meta.get("footprint", "1x1")

            if zone != "all":
                if zone == "wall" and ("wall" not in foot and f_zone != "wall"):
                    continue
                elif zone == "surface" and (foot != "surface" and f_zone != "surface"):
                    continue
                elif zone == "guide" and f_zone != "guide":
                    continue
                elif zone not in ("wall", "surface", "guide") and f_zone != zone:
                    continue

            name = meta.get("name", f_id)
            rb = tk.Radiobutton(
                self.furn_frame, text=f"[{foot}] {name}", value=f_id, variable=self.selected_furniture_id,
                bg="#181924", fg="#E2E8F0", selectcolor="#2D3250", activebackground="#181924",
                activeforeground="#38BDF8", font=("Segoe UI", 9), command=self._on_furniture_selected
            )
            rb.pack(anchor=tk.W, pady=1)

    def _on_furniture_selected(self):
        f_id = self.selected_furniture_id.get()
        meta = self.furniture_catalog.get(f_id, {})
        txt = (
            f"Mueble: {meta.get('name', f_id)}\n"
            f"Zona: {meta.get('zone', 'living').capitalize()} | Huella: {meta.get('footprint', '1x1')}\n"
            f"Canvas: {meta.get('canvas_size', [64, 64])} px\n"
            f"spriteOffset: Vector2{tuple(meta.get('sprite_offset', [0, 0]))}\n"
            f"Altura Superficie: {meta.get('surface_height', 0)} px"
        )
        if hasattr(self, "meta_lbl"):
            self.meta_lbl.config(text=txt)

    def _on_room_canvas_click(self, event):
        # Click en la habitación para seleccionar el mueble más cercano
        cw = self.room_canvas.winfo_width() or 400
        ch = self.room_canvas.winfo_height() or 400
        origin_x = cw // 2
        origin_y = int(120 * (1.0 if self.resolution == "64x128" else 0.5))
        gx, gy = furniture_engine.screen_to_grid(event.x, event.y, origin_x, origin_y, resolution=self.resolution)

        # Buscar si hay un elemento en esa baldosa
        found_idx = None
        for idx in reversed(range(len(self.room_items))):
            it = self.room_items[idx]
            if it.get("gx") == gx and it.get("gy") == gy:
                found_idx = idx
                break

        if found_idx is not None:
            self.selected_room_item_idx = found_idx
            it = self.room_items[found_idx]
            base_meta = self.furniture_catalog.get(it.get("id"), {})
            rot_meta = base_meta.get("rotations", {}).get(str(it.get("rot", 0)), base_meta)
            name = rot_meta.get("name", it.get("id"))
            rot_deg = it.get("rot", 0) * 90
            self.selected_item_lbl.config(text=f"Selección: {name} (gx={it.get('gx')}, gy={it.get('gy')}, {rot_deg}°)")
        else:
            self.avatar_grid_pos = [max(0, min(5, gx)), max(0, min(5, gy))]
            self.selected_item_lbl.config(text=f"Avatar movido a: (gx={self.avatar_grid_pos[0]}, gy={self.avatar_grid_pos[1]})")

        self.update_room_preview()

    def _rotate_selected_room_item(self, event=None):
        if self.selected_room_item_idx is not None and 0 <= self.selected_room_item_idx < len(self.room_items):
            it = self.room_items[self.selected_room_item_idx]
            it["rot"] = (it.get("rot", 0) + 1) % 4
            base_meta = self.furniture_catalog.get(it.get("id"), {})
            rot_meta = base_meta.get("rotations", {}).get(str(it["rot"]), base_meta)
            name = rot_meta.get("name", it.get("id"))
            rot_deg = it["rot"] * 90
            self.selected_item_lbl.config(text=f"Selección: {name} (gx={it.get('gx')}, gy={it.get('gy')}, {rot_deg}°)")
            self.update_room_preview()

    def _nudge_selected_tile(self, dx, dy):
        if self.selected_room_item_idx is not None and 0 <= self.selected_room_item_idx < len(self.room_items):
            it = self.room_items[self.selected_room_item_idx]
            it["gx"] = max(0, min(5, it.get("gx", 0) + dx))
            it["gy"] = max(0, min(5, it.get("gy", 0) + dy))
            base_meta = self.furniture_catalog.get(it.get("id"), {})
            rot_meta = base_meta.get("rotations", {}).get(str(it.get("rot", 0)), base_meta)
            name = rot_meta.get("name", it.get("id"))
            rot_deg = it.get("rot", 0) * 90
            self.selected_item_lbl.config(text=f"Selección: {name} (gx={it.get('gx')}, gy={it.get('gy')}, {rot_deg}°)")
            self.update_room_preview()

    def _nudge_selected_pixel(self, px, py):
        if self.selected_room_item_idx is not None and 0 <= self.selected_room_item_idx < len(self.room_items):
            it = self.room_items[self.selected_room_item_idx]
            it["nudge_x"] = it.get("nudge_x", 0) + px
            it["nudge_y"] = it.get("nudge_y", 0) + py
            self.update_room_preview()

    def _delete_selected_room_item(self):
        if self.selected_room_item_idx is not None and 0 <= self.selected_room_item_idx < len(self.room_items):
            self.room_items.pop(self.selected_room_item_idx)
            self.selected_room_item_idx = None
            self.selected_item_lbl.config(text="Selección: Ninguna")
            self.update_room_preview()

    def _clear_all_furniture(self):
        self.room_items.clear()
        self.selected_room_item_idx = None
        self.selected_item_lbl.config(text="Selección: Ninguna")
        self.update_room_preview()

    def _add_furniture_to_room(self):
        try:
            gx = int(self.place_gx_spin.get())
            gy = int(self.place_gy_spin.get())
            rot_val = self.place_rot_combo.current() if hasattr(self, "place_rot_combo") else 0
            if rot_val < 0: rot_val = 0

            f_id = self.selected_furniture_id.get()
            meta = self.furniture_catalog.get(f_id, {})
            footprint = meta.get("footprint", "1x1")

            new_item = {"id": f_id, "gx": gx, "gy": gy, "rot": rot_val, "nudge_x": 0, "nudge_y": 0}
            if footprint == "surface":
                for it in reversed(self.room_items):
                    if it.get("gx") == gx and it.get("gy") == gy and it.get("id") != f_id:
                        new_item["parent_id"] = it.get("id")
                        break

            self.room_items.append(new_item)
            self.selected_room_item_idx = len(self.room_items) - 1
            name = meta.get("name", f_id)
            rot_deg = rot_val * 90
            self.selected_item_lbl.config(text=f"Selección: {name} (gx={gx}, gy={gy}, {rot_deg}°)")
            self.update_room_preview()
        except Exception as e:
            messagebox.showerror("Error", f"No se pudo colocar el mueble: {e}")

    def _reset_room_to_default(self):
        self.room_items = furniture_engine.get_default_cozy_room_items()
        self.avatar_grid_pos = [3, 2]
        self.selected_room_item_idx = 0
        self.selected_item_lbl.config(text="Selección: Habitación Modelo")
        self.update_room_preview()

    def _export_room_image(self):
        file_path = filedialog.asksaveasfilename(
            initialdir=EXPORTS_DIR,
            title="Guardar Habitación Isométrica (.png)",
            defaultextension=".png",
            filetypes=[("Imagen PNG", "*.png")]
        )
        if not file_path: return
        room_img = furniture_engine.render_isometric_room(
            self.room_items,
            avatar_config=self.current_config,
            avatar_pos=tuple(self.avatar_grid_pos),
            avatar_dir=self.current_direction if self.current_direction != "all_4" else "down",
            resolution=self.resolution,
            selected_index=None
        )
        room_img.save(file_path, "PNG")
        messagebox.showinfo("Exportación Exitosa", f"¡Habitación Isométrica exportada con éxito!\n\nGuardada en: {file_path}")

    def update_room_preview(self):
        if not hasattr(self, "room_canvas"):
            return
        try:
            room_img = furniture_engine.render_isometric_room(
                self.room_items,
                avatar_config=self.current_config,
                avatar_pos=tuple(self.avatar_grid_pos),
                avatar_dir=self.current_direction if self.current_direction != "all_4" else "down",
                resolution=self.resolution,
                selected_index=self.selected_room_item_idx
            )
            # Escalar según resolución
            cw = self.room_canvas.winfo_width() or 420
            ch = self.room_canvas.winfo_height() or 420
            if self.resolution == "32x64":
                room_img = room_img.resize((room_img.width * 2, room_img.height * 2), Image.NEAREST)

            self.room_preview_tk_img = ImageTk.PhotoImage(room_img)
            self.room_canvas.delete("all")
            self.room_canvas.create_image(cw // 2, ch // 2, image=self.room_preview_tk_img)
        except Exception as e:
            print(f"Error al renderizar habitación: {e}")

    # -------------------------------------------------------------
    # CONTROLADORES DE EVENTOS
    # -------------------------------------------------------------
    def _apply_category_color(self, category, hex_code, preview_widget=None, label_widget=None):
        self.current_config[category]["color"] = hex_code
        if preview_widget:
            preview_widget.config(bg=hex_code)
        if label_widget:
            label_widget.config(text=hex_code)
            
        if category == "hair" and self.sync_brows_with_hair.get():
            self.current_config["eyebrows"]["color"] = hex_code
            
        if category == "body":
            self.current_config["face_shape"]["color"] = hex_code
            self.current_config["nose"]["color"] = hex_code

        self.update_avatar_preview()

    def _on_face_shape_changed(self):
        self.current_config["face_shape"]["file"] = self.face_shape_var.get()
        self.update_avatar_preview()

    def _on_hair_style_changed(self):
        self.current_config["hair"]["file"] = self.hair_var.get()
        self.update_avatar_preview()

    def _set_resolution(self, res):
        self.resolution = res
        if res == "32x64":
            self.btn_res_32.config(bg="#2563EB", fg="#FFFFFF")
            self.btn_res_64.config(bg="#2D3250", fg="#94A3B8")
            self.zoom_combo["values"] = ["2x (64x128)", "4x (128x256)", "6x (192x384)", "8x (256x512)"]
            self.zoom_var.set("6x (192x384)")
            self.zoom_level = 6
        else: # 64x128
            self.btn_res_64.config(bg="#2563EB", fg="#FFFFFF")
            self.btn_res_32.config(bg="#2D3250", fg="#94A3B8")
            self.zoom_combo["values"] = ["1x (64x128)", "2x (128x256)", "3x (192x384)", "4x (256x512)"]
            self.zoom_var.set("3x (192x384)")
            self.zoom_level = 3

        self.furniture_catalog = furniture_engine.load_furniture_catalog(self.resolution)
        self._populate_furniture_list()
        self._on_furniture_selected()
        self.update_avatar_preview()
        self.update_room_preview()

    def _on_zoom_changed(self, event=None):
        val_str = self.zoom_var.get()
        try:
            mult = int(val_str.split("x")[0])
            self.zoom_level = mult
        except Exception:
            self.zoom_level = 3
        self.update_avatar_preview()

    def _on_item_changed(self, category, filename):
        self.current_config[category]["file"] = filename
        self.update_avatar_preview()

    def _set_bg_mode(self, mode):
        self.bg_mode = mode
        self.update_avatar_preview()

    # -------------------------------------------------------------
    # RENDERIZADO DEL PREVIEW EN VIVO
    # -------------------------------------------------------------
    def update_avatar_preview(self):
        f = self.current_frame
        cw, ch = (32, 64) if self.resolution == "32x64" else (64, 128)
        
        if self.current_direction == "all_4":
            w_single = cw * self.zoom_level
            h_single = ch * self.zoom_level
            combined = Image.new("RGBA", (w_single * 4 + 24, h_single), (0, 0, 0, 0))
            
            for idx, d in enumerate(["down", "left", "right", "up"]):
                frame_img = color_engine.composite_avatar(self.current_config, direction=d, frame=f, resolution=self.resolution)
                frame_scaled = frame_img.resize((w_single, h_single), Image.NEAREST)
                combined.alpha_composite(frame_scaled, (idx * (w_single + 8), 0))
            target_sprite = combined
        else:
            frame_img = color_engine.composite_avatar(self.current_config, direction=self.current_direction, frame=f, resolution=self.resolution)
            target_w = cw * self.zoom_level
            target_h = ch * self.zoom_level
            target_sprite = frame_img.resize((target_w, target_h), Image.NEAREST)

        target_w, target_h = target_sprite.size
        canvas_w = max(target_w + 32, self.canvas.winfo_width() or 360)
        canvas_h = max(target_h + 32, self.canvas.winfo_height() or 460)

        bg_img = Image.new("RGBA", (canvas_w, canvas_h), (0, 0, 0, 0))
        d = ImageDraw.Draw(bg_img)

        if self.bg_mode == "checkerboard":
            tile_size = 12
            for ty in range(0, canvas_h, tile_size):
                for tx in range(0, canvas_w, tile_size):
                    col = (30, 32, 44, 255) if ((tx // tile_size) + (ty // tile_size)) % 2 == 0 else (22, 24, 34, 255)
                    d.rectangle([tx, ty, tx + tile_size, ty + tile_size], fill=col)
        elif self.bg_mode == "dark":
            d.rectangle([0, 0, canvas_w, canvas_h], fill=(18, 19, 26, 255))
        elif self.bg_mode == "light":
            d.rectangle([0, 0, canvas_w, canvas_h], fill=(240, 243, 246, 255))
        elif self.bg_mode == "snes_gradient":
            for y in range(canvas_h):
                factor = y / canvas_h
                r = int(24 + (54 - 24) * factor)
                g = int(32 + (84 - 32) * factor)
                b = int(68 + (130 - 68) * factor)
                d.line([(0, y), (canvas_w, y)], fill=(r, g, b, 255))

        offset_x = (canvas_w - target_w) // 2
        offset_y = (canvas_h - target_h) // 2
        bg_img.alpha_composite(target_sprite, (offset_x, offset_y))

        self.preview_tk_img = ImageTk.PhotoImage(bg_img)
        self.canvas.delete("all")
        self.canvas.create_image(canvas_w // 2, canvas_h // 2, image=self.preview_tk_img)

    # -------------------------------------------------------------
    # RANDOMIZER & PRESETS
    # -------------------------------------------------------------
    def randomize_avatar(self):
        shapes_list = ["face_oval.png", "face_round.png", "face_sharp_v.png", "face_square_jaw.png", "face_heart.png"]
        self.face_shape_var.set(random.choice(shapes_list))
        self.current_config["face_shape"]["file"] = self.face_shape_var.get()

        skin_color = random.choice(RETRO_PALETTES["skin"])[1]
        self.current_config["body"]["color"] = skin_color
        self.current_config["face_shape"]["color"] = skin_color
        self.current_config["nose"]["color"] = skin_color

        eyes_list = [
            "eyes_shoujo_sparkle.png", "eyes_stardew_cute.png", "eyes_jrpg_classic.png",
            "eyes_adventurer_serious.png", "eyes_sleepy_calm.png", "eyes_cateye_sly.png",
            "eyes_mystic_glow.png", "eyes_happy_closed.png", "eyes_dot_chibi.png", "eyes_wink.png"
        ]
        self.eyes_var.set(random.choice(eyes_list))
        self.current_config["eyes"]["file"] = self.eyes_var.get()
        self.current_config["eyes"]["color"] = random.choice(RETRO_PALETTES["eyes"])[1]

        brows_list = ["brows_normal.png", "brows_thick.png", "brows_serious.png", "brows_arched.png"]
        self.brows_var.set(random.choice(brows_list))
        self.current_config["eyebrows"]["file"] = self.brows_var.get()

        nose_list = ["nose_subtle.png", "nose_pointed.png", "nose_button.png"]
        self.nose_var.set(random.choice(nose_list))
        self.current_config["nose"]["file"] = self.nose_var.get()

        mouth_list = ["mouth_smile.png", "mouth_neutral.png", "mouth_open_smile.png", "mouth_smirk.png", "mouth_lipstick.png"]
        self.mouth_var.set(random.choice(mouth_list))
        self.current_config["mouth"]["file"] = self.mouth_var.get()

        detail_list = ["detail_none.png", "detail_blush.png", "detail_freckles.png", "detail_scar.png"]
        self.detail_var.set(random.choice(detail_list))
        self.current_config["face_detail"]["file"] = self.detail_var.get()

        hairs_list = [
            "hair_farm_braids.png", "hair_adventurer_spiky.png", "hair_long_flowing.png",
            "hair_bob_bangs.png", "hair_curly_locks.png", "hair_high_ponytail.png",
            "hair_twintails.png", "hair_messy_wanderer.png"
        ]
        self.hair_var.set(random.choice(hairs_list))
        self.current_config["hair"]["file"] = self.hair_var.get()
        hair_color = random.choice(RETRO_PALETTES["hair"])[1]
        self.current_config["hair"]["color"] = hair_color
        self.current_config["eyebrows"]["color"] = hair_color

        tops_list = [
            "top_flannel_shirt.png", "top_overalls_bib.png", "top_traveler_tunic.png",
            "top_adventurer_coat.png", "top_tshirt.png", "top_hoodie.png", "top_crop_top.png"
        ]
        self.tops_var.set(random.choice(tops_list))
        self.current_config["tops"]["file"] = self.tops_var.get()
        self.current_config["tops"]["color"] = random.choice(RETRO_PALETTES["clothing"])[1]

        bottoms_list = [
            "bottom_farmer_overalls.png", "bottom_adventurer_pants.png", "bottom_rustic_skirt.png",
            "bottom_skirt_pleated.png", "bottom_shorts.png"
        ]
        self.bottoms_var.set(random.choice(bottoms_list))
        self.current_config["bottoms"]["file"] = self.bottoms_var.get()
        self.current_config["bottoms"]["color"] = random.choice(RETRO_PALETTES["clothing"])[1]

        shoes_list = ["shoes_adventurer_boots.png", "shoes_farmer_boots.png", "shoes_sneakers.png", "shoes_sandals.png"]
        self.shoes_var.set(random.choice(shoes_list))
        self.current_config["shoes"]["file"] = self.shoes_var.get()
        self.current_config["shoes"]["color"] = random.choice(RETRO_PALETTES["clothing"])[1]

        acc_list = [
            "acc_straw_hat.png", "acc_traveler_hood.png", "acc_hair_flower.png",
            "acc_scholar_glasses.png", "acc_neck_bandana.png", "acc_satchel_bag.png",
            "acc_none.png", "acc_none.png"
        ]
        self.acc_var.set(random.choice(acc_list))
        self.current_config["accessories"]["file"] = self.acc_var.get()
        self.current_config["accessories"]["color"] = random.choice(RETRO_PALETTES["clothing"])[1]

        self.update_avatar_preview()

    def reload_from_disk(self):
        color_engine.clear_disk_cache()
        self.update_avatar_preview()
        messagebox.showinfo("Recarga Completa", "¡Se ha recargado la memoria caché!\nCualquier cambio hecho en los archivos PNG de la carpeta 'assets/' ahora se refleja en vivo.")

    def reset_to_default(self):
        self.current_config = {
            "body": {"file": "body_base.png", "color": "#FCD5B5"},
            "face_shape": {"file": "face_oval.png", "color": "#FCD5B5"},
            "face_detail": {"file": "detail_blush.png", "color": "#FF7777"},
            "mouth": {"file": "mouth_smile.png", "color": "#C44242"},
            "nose": {"file": "nose_subtle.png", "color": "#FCD5B5"},
            "eyes": {"file": "eyes_jrpg_classic.png", "color": "#059669"},
            "eyebrows": {"file": "brows_normal.png", "color": "#C85A2A"},
            "hair": {"file": "hair_farm_braids.png", "color": "#C85A2A"},
            "bottoms": {"file": "bottom_farmer_overalls.png", "color": "#2563EB"},
            "shoes": {"file": "shoes_farmer_boots.png", "color": "#78350F"},
            "tops": {"file": "top_flannel_shirt.png", "color": "#DC2626"},
            "accessories": {"file": "acc_straw_hat.png", "color": "#EAB308"}
        }
        self.face_shape_var.set(self.current_config["face_shape"]["file"])
        self.eyes_var.set(self.current_config["eyes"]["file"])
        self.brows_var.set(self.current_config["eyebrows"]["file"])
        self.nose_var.set(self.current_config["nose"]["file"])
        self.mouth_var.set(self.current_config["mouth"]["file"])
        self.detail_var.set(self.current_config["face_detail"]["file"])
        self.hair_var.set(self.current_config["hair"]["file"])
        self.tops_var.set(self.current_config["tops"]["file"])
        self.bottoms_var.set(self.current_config["bottoms"]["file"])
        self.shoes_var.set(self.current_config["shoes"]["file"])
        self.acc_var.set(self.current_config["accessories"]["file"])
        self.update_avatar_preview()

    def save_preset_dialog(self):
        file_path = filedialog.asksaveasfilename(
            initialdir=PRESETS_DIR,
            title="Guardar Personaje Preset (.json)",
            defaultextension=".json",
            filetypes=[("Archivos JSON", "*.json")]
        )
        if file_path:
            try:
                with open(file_path, "w", encoding="utf-8") as f:
                    json.dump(self.current_config, f, indent=4, ensure_ascii=False)
                messagebox.showinfo("Éxito", f"Personaje guardado correctamente en:\n{os.path.basename(file_path)}")
            except Exception as e:
                messagebox.showerror("Error", f"No se pudo guardar el archivo:\n{e}")

    def load_preset_dialog(self):
        file_path = filedialog.askopenfilename(
            initialdir=PRESETS_DIR,
            title="Cargar Personaje Preset (.json)",
            filetypes=[("Archivos JSON", "*.json")]
        )
        if file_path:
            try:
                with open(file_path, "r", encoding="utf-8") as f:
                    loaded_cfg = json.load(f)
                self.current_config.update(loaded_cfg)
                self.face_shape_var.set(self.current_config.get("face_shape", {}).get("file", "face_oval.png"))
                self.eyes_var.set(self.current_config.get("eyes", {}).get("file", "eyes_jrpg_classic.png"))
                self.brows_var.set(self.current_config.get("eyebrows", {}).get("file", "brows_normal.png"))
                self.nose_var.set(self.current_config.get("nose", {}).get("file", "nose_subtle.png"))
                self.mouth_var.set(self.current_config.get("mouth", {}).get("file", "mouth_smile.png"))
                self.detail_var.set(self.current_config.get("face_detail", {}).get("file", "detail_none.png"))
                self.hair_var.set(self.current_config.get("hair", {}).get("file", "hair_farm_braids.png"))
                self.tops_var.set(self.current_config.get("tops", {}).get("file", "top_flannel_shirt.png"))
                self.bottoms_var.set(self.current_config.get("bottoms", {}).get("file", "bottom_farmer_overalls.png"))
                self.shoes_var.set(self.current_config.get("shoes", {}).get("file", "shoes_farmer_boots.png"))
                self.acc_var.set(self.current_config.get("accessories", {}).get("file", "acc_none.png"))
                self.update_avatar_preview()
                messagebox.showinfo("Éxito", f"Personaje '{os.path.basename(file_path)}' cargado exitosamente.")
            except Exception as e:
                messagebox.showerror("Error", f"No se pudo cargar el preset:\n{e}")

    # -------------------------------------------------------------
    # EXPORTACIÓN AVANZADA (PNG / SPRITESHEET / GIF)
    # -------------------------------------------------------------
    def open_export_dialog(self):
        dlg = tk.Toplevel(self.root)
        dlg.title("Exportar Avatar - PNG / Spritesheet / GIF")
        dlg.geometry("520x480")
        dlg.resizable(False, False)
        dlg.configure(bg="#181924")
        dlg.transient(self.root)
        dlg.grab_set()

        tk.Label(dlg, text="🖼️ Opciones de Exportación", font=("Segoe UI", 12, "bold"), bg="#181924", fg="#38BDF8").pack(pady=10)

        type_frame = ttk.LabelFrame(dlg, text=" Formato de Exportación ", padding=10)
        type_frame.pack(fill=tk.X, padx=16, pady=4)

        export_type_var = tk.StringVar(value="spritesheet")
        types = [
            ("🎮 Spritesheet Completo 4x4 (Para Unity / Godot / RPG Maker / Pygame)", "spritesheet"),
            ("🎬 GIF Animado de Caminata (Bucle infinito)", "gif"),
            ("🖼️ Imagen PNG Individual (Dirección actual y cuadro actual)", "single_png"),
            ("📦 Todas las Capas Base PNG (Guardar biblioteca completa en /assets)", "all_layers"),
        ]
        for label, val in types:
            rb = tk.Radiobutton(type_frame, text=label, value=val, variable=export_type_var, bg="#181924", fg="#E2E8F0", selectcolor="#2D3250", activebackground="#181924", activeforeground="#38BDF8", font=("Segoe UI", 9))
            rb.pack(anchor=tk.W, pady=2)

        res_frame = ttk.LabelFrame(dlg, text=" Escala de Resolución ", padding=10)
        res_frame.pack(fill=tk.X, padx=16, pady=4)

        scale_var = tk.IntVar(value=2)
        cw, ch = (32, 64) if self.resolution == "32x64" else (64, 128)
        scales = [
            (f"1x - Pixel Art Nativo ({cw}x{ch} por cuadro / {cw*4}x{ch*4} Spritesheet)", 1),
            (f"2x - HD Nítido ({cw*2}x{ch*2} por cuadro / {cw*8}x{ch*8} Spritesheet)", 2),
            (f"4x - Super HD ({cw*4}x{ch*4} por cuadro / {cw*16}x{ch*16} Spritesheet)", 4),
        ]
        for label, val in scales:
            rb = tk.Radiobutton(res_frame, text=label, value=val, variable=scale_var, bg="#181924", fg="#E2E8F0", selectcolor="#2D3250", activebackground="#181924", activeforeground="#38BDF8", font=("Segoe UI", 9))
            rb.pack(anchor=tk.W, pady=1)

        bg_frame = ttk.LabelFrame(dlg, text=" Fondo de Imagen ", padding=10)
        bg_frame.pack(fill=tk.X, padx=16, pady=4)

        export_bg_var = tk.StringVar(value="transparent")
        bgs = [
            ("Transparente (Canal Alfa PNG/GIF)", "transparent"),
            ("Color Blanco Sólido", "white"),
            ("Color Oscuro Retro (#181924)", "dark"),
        ]
        for label, val in bgs:
            rb = tk.Radiobutton(bg_frame, text=label, value=val, variable=export_bg_var, bg="#181924", fg="#E2E8F0", selectcolor="#2D3250", activebackground="#181924", activeforeground="#38BDF8", font=("Segoe UI", 9))
            rb.pack(anchor=tk.W, pady=1)

        def do_export():
            exp_type = export_type_var.get()
            scale = scale_var.get()
            bg_choice = export_bg_var.get()
            res_str = self.resolution

            if exp_type == "spritesheet":
                file_path = filedialog.asksaveasfilename(
                    initialdir=EXPORTS_DIR,
                    title="Guardar Spritesheet 4x4 (.png)",
                    defaultextension=".png",
                    filetypes=[("Imagen PNG", "*.png")]
                )
                if not file_path: return
                
                sheet = color_engine.generate_spritesheet(self.current_config, scale=scale, resolution=res_str)
                if bg_choice != "transparent":
                    bg_col = (255, 255, 255, 255) if bg_choice == "white" else (24, 25, 36, 255)
                    final_img = Image.new("RGBA", sheet.size, bg_col)
                    final_img.alpha_composite(sheet)
                else:
                    final_img = sheet
                final_img.save(file_path, "PNG")
                dlg.destroy()
                messagebox.showinfo("Exportación Exitosa", f"¡Spritesheet 4x4 ({res_str}) exportado con éxito a {final_img.size[0]}x{final_img.size[1]} px!\n\nGuardado en: {file_path}")

            elif exp_type == "gif":
                file_path = filedialog.asksaveasfilename(
                    initialdir=EXPORTS_DIR,
                    title="Guardar GIF Animado de Caminata (.gif)",
                    defaultextension=".gif",
                    filetypes=[("GIF Animado", "*.gif")]
                )
                if not file_path: return

                target_dir = self.current_direction if self.current_direction != "all_4" else "down"
                frames = color_engine.generate_walk_gif(self.current_config, direction=target_dir, scale=scale, resolution=res_str)
                
                final_frames = []
                for fr in frames:
                    if bg_choice != "transparent":
                        bg_col = (255, 255, 255, 255) if bg_choice == "white" else (24, 25, 36, 255)
                        f_bg = Image.new("RGBA", fr.size, bg_col)
                        f_bg.alpha_composite(fr)
                        final_frames.append(f_bg)
                    else:
                        final_frames.append(fr)

                duration_ms = int(1000 / max(1, self.fps))
                final_frames[0].save(
                    file_path,
                    save_all=True,
                    append_images=final_frames[1:],
                    duration=duration_ms,
                    loop=0,
                    disposal=2
                )
                dlg.destroy()
                messagebox.showinfo("Exportación Exitosa", f"¡GIF Animado ({res_str}) exportado con éxito!\n\nGuardado en: {file_path}")

            elif exp_type == "all_layers":
                def_folder = "assets_32x64" if res_str == "32x64" else "assets"
                folder_path = filedialog.askdirectory(
                    initialdir=def_folder if os.path.exists(def_folder) else ".",
                    title=f"Seleccionar carpeta para guardar capas PNG ({res_str})"
                )
                if not folder_path: return
                
                if res_str == "32x64":
                    import sprite_generator_32x64
                    total = sprite_generator_32x64.export_all_layers_to_disk(folder_path)
                else:
                    import sprite_generator
                    total = sprite_generator.export_all_layers_to_disk(folder_path)
                dlg.destroy()
                messagebox.showinfo("Exportación Exitosa", f"¡Se han exportado {total} archivos PNG individuales ({res_str}) organizados por carpetas en:\n{folder_path}")

            else: # single_png
                file_path = filedialog.asksaveasfilename(
                    initialdir=EXPORTS_DIR,
                    title="Guardar Cuadro Individual (.png)",
                    defaultextension=".png",
                    filetypes=[("Imagen PNG", "*.png")]
                )
                if not file_path: return

                target_dir = self.current_direction if self.current_direction != "all_4" else "down"
                base_img = color_engine.composite_avatar(self.current_config, direction=target_dir, frame=self.current_frame, resolution=res_str)
                out_w = cw * scale
                out_h = ch * scale
                scaled_img = base_img.resize((out_w, out_h), Image.NEAREST)

                if bg_choice != "transparent":
                    bg_col = (255, 255, 255, 255) if bg_choice == "white" else (24, 25, 36, 255)
                    final_img = Image.new("RGBA", (out_w, out_h), bg_col)
                    final_img.alpha_composite(scaled_img)
                else:
                    final_img = scaled_img

                final_img.save(file_path, "PNG")
                dlg.destroy()
                messagebox.showinfo("Exportación Exitosa", f"¡Cuadro individual ({res_str}) exportado a {out_w}x{out_h} px!\n\nGuardado en: {file_path}")

        btn_box = tk.Frame(dlg, bg="#181924")
        btn_box.pack(fill=tk.X, padx=16, pady=10)

        tk.Button(btn_box, text="Cancelar", bg="#334155", fg="#FFFFFF", font=("Segoe UI", 9), bd=0, padx=12, pady=6, cursor="hand2", command=dlg.destroy).pack(side=tk.LEFT)
        tk.Button(btn_box, text="💾 Exportar Archivo", bg="#2563EB", fg="#FFFFFF", font=("Segoe UI", 10, "bold"), activebackground="#3B82F6", bd=0, padx=16, pady=6, cursor="hand2", command=do_export).pack(side=tk.RIGHT)

def main():
    root = tk.Tk()
    app = AvatarCreatorApp(root)
    root.mainloop()

if __name__ == "__main__":
    main()
