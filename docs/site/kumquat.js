/* Kumquat — site script (vanilla, no dependencies) */
(function () {
  "use strict";

  var reduce = window.matchMedia && window.matchMedia("(prefers-reduced-motion: reduce)").matches;
  function $(s, r) { return (r || document).querySelector(s); }
  function $$(s, r) { return Array.prototype.slice.call((r || document).querySelectorAll(s)); }
  function clamp(v, a, b) { return Math.max(a, Math.min(b, v)); }

  /* =====================================================================
     Translations
     ===================================================================== */
  var ES = {
    skip: "Saltar al contenido",
    nav_how: "Cómo funciona",
    nav_formats: "Formatos",
    nav_custom: "Personaliza",
    nav_privacy: "Privacidad",
    nav_faq: "Preguntas",
    nav_download: "Descargar",
    hero_pill: "Gratis y de código abierto, hecho para macOS",
    hero_title: '<span class="w">Arrastra.</span> <span class="w">Pulsa <span class="shift" aria-label="Mayúsculas">⇧</span>.</span> <span class="w"><span class="grad-text">Suelta.</span></span>',
    hero_sub: "Un conversor de archivos gratuito que vive dentro de tu arrastrar y soltar. Agarra cualquier archivo, muévelo un poco, pulsa Mayúsculas y suéltalo sobre un formato. Imágenes, PDF, documentos, video y audio, convertidos ahí mismo en tu Mac.",
    btn_download: "Descargar para Mac",
    btn_github: "Ver en GitHub",
    meta_free: "Gratis y de código abierto",
    meta_universal: "Apple Silicon e Intel",
    install_label: "O instálalo con una sola línea en Terminal (sin avisos de seguridad):",
    demo_label: "Demo interactiva: un escritorio de Mac donde puedes arrastrar un archivo, abrir el anillo de Kumquat y soltarlo sobre un formato.",
    demo_caption: "Demo en vivo. Arrastra un archivo del escritorio de arriba, pulsa <kbd>⇧</kbd> mientras lo sostienes y suéltalo sobre una porción. En el móvil, el anillo se abre solo.",
    mb_file: "Archivo", mb_edit: "Edición", mb_view: "Visualización", mb_go: "Ir", mb_window: "Ventana",
    hero_alt: "Una foto HEIC arrastrada en el escritorio de un Mac. Bajo el cursor se abre un anillo de cristal con formatos y la porción JPG resaltada, y una notificación muestra el archivo convertido y cuánto ha reducido su tamaño.",

    st1: "formatos incluidos",
    st2: "idiomas",
    st3: "subidas, cuentas o rastreadores",
    st4: "gratis y de código abierto",

    how_eyebrow: "Cómo funciona",
    how_title: "Un gesto en lugar de cinco menús.",
    how_lead: "Convertir un archivo suele significar abrir una app, buscar Exportar…, elegir un formato y una carpeta. Kumquat lo hace a mitad de un arrastre.",
    old_tag: "Lo de siempre",
    old_count: "5 pasos, cada vez",
    om_app: "Vista Previa",
    om_open: "Abrir…", om_close: "Cerrar", om_export: "Exportar…", om_pdf: "Exportar como PDF…", om_print: "Imprimir…",
    old_1: "Abrir el archivo en una app",
    old_2: "Buscar Archivo → Exportar…",
    old_3: "Elegir un formato en un menú",
    old_4: "Escoger una carpeta",
    old_5: "Pulsar Guardar y luego ir a buscarlo",
    new_tag: "Con Kumquat",
    new_count: "1 gesto",
    s1_t: "Empieza a arrastrar",
    s1_d: "Toma cualquier archivo (o varios) en Finder o en el escritorio y muévelo un poco para que macOS inicie el arrastre.",
    s2_t: "Pulsa <kbd>⇧</kbd> Mayúsculas",
    s2_d: "Sin soltar el archivo, pulsa Mayúsculas. Justo bajo el cursor se abre un anillo de cristal con formatos. Vuelve a pulsar <kbd>⇧</kbd> para pasar de <b>Convertir</b> a <b>Herramientas</b> y viceversa.",
    s3_t: "Suéltalo sobre una porción",
    s3_d: "El archivo nuevo se guarda junto al original, que nunca se modifica. Una notificación te muestra el cambio de tamaño, con <b>Mostrar en Finder</b>, <b>Abrir</b> y <b>Deshacer</b>.",
    how_note: "¿Cambiaste de idea? Suéltalo en el centro del anillo, o en cualquier otro lugar, y no pasa nada.",

    tools_eyebrow: "Dos páginas, un anillo",
    tools_title: "Conviértelo. O arréglalo.",
    tools_lead: "El anillo sabe qué estás arrastrando. Si es una foto, verás formatos de imagen; si es un PDF, imágenes, texto y Word. Pulsa <kbd>⇧</kbd> otra vez y el mismo anillo se convierte en Herramientas: comprimir, cambiar el tamaño, recortar, quitar el fondo, extraer el texto y mucho más.",
    tools_c1: 'Ve de un vistazo lo que cambió: <span class="notif-sample">2,4 MB → 610 KB · 75 % menos</span>',
    tools_c2: "Suelta varios archivos a la vez. Se procesan en segundo plano.",
    tools_c3: "¿Te equivocaste? <b>Deshacer</b> en la notificación elimina el archivo nuevo.",
    tools_alt: "La página Herramientas del anillo con Quitar fondo resaltado, junto a tres notificaciones de resultados",
    ex_pick: "Elige un archivo",
    ex_hint: "Apunta a una porción. Pulsa <kbd>⇧</kbd> en tu teclado, o toca la píldora, para cambiar de página.",
    shot_convert: "Convertir",
    shot_tools: "Herramientas",
    shot_cap: "Capturas reales de Kumquat en macOS.",

    fmt_eyebrow: "Qué convierte",
    fmt_title: "Casi todo lo que puedas arrastrar.",
    fmt_lead: "Funciona con los frameworks que ya vienen con macOS. No hay nada extra que instalar y nada se envía a ningún sitio.",
    lbl_in: "Suelta",
    lbl_out: "Obtén",
    lbl_tools: "Herramientas",
    lbl_compress: "Comprimir",
    lbl_extract: "Extraer",
    lbl_both: "En ambos sentidos",
    f_img: "Imágenes",
    f_doc: "Documentos",
    f_data: "Hojas de cálculo y datos",
    f_video: "Video",
    f_audio: "Audio",
    f_arch: "Archivos comprimidos",
    f_subs: "Subtítulos",
    t_compress: "Comprimir",
    t_resize: "Cambiar tamaño",
    t_crop: "Recortar",
    t_addbg: "Añadir fondo",
    t_rmbg: "Quitar fondo",
    t_text: "Obtener texto",
    t_meta: "Borrar metadatos",
    t_rotate: "Rotar",
    t_flip: "Voltear",
    t_bw: "Blanco y negro",
    t_merge: "Combinar",
    t_split: "Dividir",
    t_protect: "Proteger con contraseña",
    t_mute: "Silenciar",
    o_htmltable: "Tabla HTML",
    o_m4a: "Audio M4A",
    o_frames: "Fotogramas en una carpeta",
    o_anyfiles: "Cualquier archivo o carpeta",
    f_img_note: "Varias imágenes se convierten en <strong>un solo PDF</strong>. <strong>Quitar fondo</strong> usa IA en el propio dispositivo y también elimina fondos lisos detrás de firmas y logotipos. <strong>Añadir fondo</strong> agrega márgenes, esquinas redondeadas, sombra y una proporción. <strong>Obtener texto</strong> copia lo que lee al portapapeles. <strong>Borrar metadatos</strong> elimina la ubicación y los datos de la cámara.",
    f_pdf_note: "Exporta cada página como una imagen o el documento entero como <strong>una sola imagen larga</strong>. El OCR hace que los PDF escaneados se puedan buscar y copiar.",
    f_doc_note: "Convierte tus notas en PDF, un archivo Markdown en Word o un artículo en un libro electrónico.",
    f_data_note: "De cualquiera de ellos a cualquier otro, además de una tabla limpia que puedes imprimir o compartir.",
    eng_eyebrow: "Motores opcionales",
    eng_title: "¿Tienes FFmpeg, LibreOffice o Ghostscript?",
    eng_text: "Kumquat no los necesita. Pero si ya tienes alguno instalado (con Homebrew o con el instalador de LibreOffice), lo detecta y añade más formatos al anillo.",
    eng_lo: "Excel, PowerPoint y Word con todo su formato",
    eng_gs: "Compresión de PDF más potente",

    ways_eyebrow: "Sin arrastrar",
    ways_title: "Otras formas de usarlo.",
    ways_lead: "El anillo es el camino más rápido, pero no el único. Kumquat espera tranquilo en la barra de menús y aparece donde ya trabajas.",
    w1_t: "Barra de menús",
    w1_d: 'Haz clic en el icono y elige <span class="path">Convertir un archivo…</span>, o suelta los archivos directamente sobre el icono.',
    w2_t: "Clic derecho en Finder",
    w2_d: '<span class="path">Servicios → Convertir con Kumquat</span>, o <span class="path">Abrir con → Kumquat</span>.',
    w3_t: "Atajo global",
    w3_d: "Selecciona archivos en Finder y pulsa <kbd>⌃</kbd> <kbd>⌥</kbd> <kbd>K</kbd>. El anillo se abre con lo que tengas seleccionado.",
    w4_t: "Carpetas vigiladas",
    w4_d: "Elige una carpeta y un formato. Todo lo que llegue ahí se convierte automáticamente.",
    cli_c: "#  Y desde Terminal, con la herramienta de línea de comandos kumquat:",

    cu_eyebrow: "Personaliza",
    cu_title: "Tu anillo, tus colores.",
    cu_lead: "Todo lo del anillo se puede cambiar en Ajustes, con una vista previa en vivo mientras lo haces.",
    themes_alt: "Ocho anillos de Kumquat con distintos temas de color sobre un fondo oscuro",
    th_prev: "Tema anterior",
    th_next: "Tema siguiente",
    o1_t: "8 temas, o tu propio degradado",
    o1_d: "Elige una paleta o mezcla dos colores cualesquiera en una a tu medida.",
    o2_t: "Esmerilado, Liquid Glass o Sólido",
    o2_d: "En claro, en oscuro o siguiendo al sistema.",
    o3_t: "Tamaño, opacidad y etiquetas",
    o3_d: "Haz el anillo más grande o más pequeño, las porciones más opacas o más transparentes, con iconos, texto o ambos.",
    o4_t: "Tu tecla de activación",
    o4_d: "Abre el anillo con <kbd>⇧</kbd>, <kbd>⌥</kbd>, <kbd>⌃</kbd> o <kbd>⌘</kbd>.",
    o5_t: "Solo las porciones que usas",
    o5_d: "Elige qué formatos y herramientas aparecen, y arrástralos para ordenarlos a tu gusto.",
    o6_t: "Dónde y cómo se guarda",
    o6_d: "Junto al original, en una subcarpeta o en la carpeta que elijas, con tus propios ajustes de calidad.",
    o7_t: "Tu idioma",
    o7_d: "English, Español, Português, Français, Deutsch, Italiano, 日本語, 한국어 y 简体中文. Más traducciones son bienvenidas en GitHub.",
    settings_alt: "Ventana de Ajustes de Kumquat en el panel Apariencia, con una vista previa del anillo y muestras de temas",
    settings_cap: "Ajustes → Apariencia, con una vista previa del anillo en vivo.",

    pr_eyebrow: "Privacidad",
    pr_title: "Tus archivos nunca salen de tu Mac.",
    pr_lead: "Cada conversión, cada fondo eliminado y cada texto reconocido se procesa en tu propio equipo. No hay nada en lo que registrarse ni nada que vigile lo que haces.",
    pr1_t: "Sin cuentas",
    pr1_d: "Descárgalo y listo.",
    pr2_t: "Sin subidas",
    pr2_d: "Los archivos se procesan en local.",
    pr3_t: "Sin analíticas",
    pr3_d: "Ningún tipo de rastreo.",
    pr4_t: "Código abierto",
    pr4_d: "Puedes leer cada línea. Licencia MIT.",
    pr_foot: "La única vez que usa la red es para una comprobación opcional de nuevas versiones en GitHub.",

    faq_eyebrow: "Preguntas frecuentes",
    faq_title: "Preguntas y respuestas.",
    q1: "macOS dice que no puede verificar la app. ¿Qué hago?",
    a1: "<p>Kumquat todavía no está notarizado por Apple, así que la primera vez que lo abres desde el .dmg, macOS muestra un aviso. Cierra el aviso y ve a <b>Ajustes del Sistema → Privacidad y seguridad</b>, desplázate hacia abajo y haz clic en <b>Abrir igualmente</b>. Solo tienes que hacerlo una vez.</p><p>¿Prefieres saltártelo? El comando de instalación de una línea copia Kumquat en Aplicaciones sin que aparezca el aviso. Vuelve a ejecutarlo cuando quieras para actualizar.</p>",
    q2: "¿Necesita permisos especiales?",
    a2: "<p>No. Kumquat no pide acceso a Accesibilidad ni a Grabación de pantalla. Detecta los arrastres y las teclas modificadoras con eventos estándar del sistema, y nunca lee tu pantalla ni lo que escribes.</p>",
    q3: "¿De verdad es gratis?",
    a3: "<p>Sí. Kumquat es de código abierto con licencia MIT. Sin periodo de prueba, sin versión de pago y sin anuncios.</p>",
    q4: "¿En qué Mac funciona?",
    a4: "<p>En cualquier Mac con macOS 14 Sonoma o posterior. Es una app universal, así que funciona de forma nativa tanto en Apple Silicon como en Intel.</p>",
    q5: "¿Dónde se guardan los archivos convertidos?",
    a5: "<p>Por defecto, junto al original, con un nombre nuevo como <code>Foto 2.jpg</code> si el nombre ya existe. También puedes guardarlos en una subcarpeta o en la carpeta que elijas. El original nunca se modifica, y <b>Deshacer</b> en la notificación elimina el archivo nuevo.</p>",
    q6: "¿Encontraste un error o falta algún formato?",
    a6: '<p><a href="https://github.com/iandifilippo/Kumquat/issues">Abre un issue en GitHub</a>. Las ideas, los reportes de errores y los pull requests son bienvenidos.</p>',

    final_title: "Tu próximo arrastre puede ser una conversión.",
    final_lead: "Gratis, de código abierto y listo en unos segundos.",
    ft_download: "Descargar",
    ft_issues: "Reportar un problema",
    ft_license: "Licencia MIT",
    ft_small: "Kumquat es software libre y de código abierto para macOS 14 y posterior. Mac, macOS y Finder son marcas comerciales de Apple Inc."
  };

  var UI = {
    en: {
      title: "Kumquat — Free file converter for Mac",
      desc: document.querySelector('meta[name="description"]').getAttribute("content"),
      copy: "Copy", copied: "Copied",
      convert: "Convert", tools: "Tools",
      base: { photo: "Photo", pdf: "Invoice", md: "Notes", mov: "Clip" },
      ex: { photo: "Photo", pdf: "PDF", mov: "Video", md: "Notes" },
      tl: { compress: "Compress", resize: "Resize", crop: "Crop", rmbg: "Remove BG", text: "Get Text", rotate: "Rotate", meta: "Metadata", addbg: "Add BG", split: "Split", protect: "Protect", ocr: "OCR", mute: "Mute" },
      sfx: { compress: "Compressed", resize: "Resized", crop: "Cropped", rmbg: "No Background", rotate: "Rotated", meta: "Clean", addbg: "Background", split: "Pages", protect: "Protected", ocr: "OCR", mute: "Muted" },
      hint: {
        idle: "Drag a file on the desktop", auto: "Watch, or grab a file yourself",
        drag: "Now tap ⇧ Shift", dragTouch: "Keep holding…",
        ring: "Drop on a slice · ⇧ switches pages", ringTouch: "Drop on a slice",
        kbd: "Arrows pick · Enter drops · Esc cancels",
        busy: "Converting…", done: "Done! Try another file"
      },
      smaller: "smaller", clip: "Text copied to clipboard", from: "from",
      show: "Show in Finder", open: "Open", undo: "Undo"
    },
    es: {
      title: "Kumquat — Conversor de archivos gratis para Mac",
      desc: "Kumquat es una app gratuita y de código abierto para la barra de menús de macOS. Agarra cualquier archivo, muévelo un poco, pulsa Mayúsculas y suéltalo sobre un anillo de formatos para convertirlo. Imágenes, PDF, documentos, video y audio, todo en tu Mac.",
      copy: "Copiar", copied: "Copiado",
      convert: "Convertir", tools: "Herramientas",
      base: { photo: "Foto", pdf: "Factura", md: "Notas", mov: "Clip" },
      ex: { photo: "Foto", pdf: "PDF", mov: "Video", md: "Notas" },
      tl: { compress: "Comprimir", resize: "Tamaño", crop: "Recortar", rmbg: "Quitar fondo", text: "Texto", rotate: "Rotar", meta: "Metadatos", addbg: "Fondo", split: "Dividir", protect: "Proteger", ocr: "OCR", mute: "Silenciar" },
      sfx: { compress: "comprimido", resize: "redimensionado", crop: "recortado", rmbg: "sin fondo", rotate: "rotado", meta: "sin metadatos", addbg: "con fondo", split: "páginas", protect: "protegido", ocr: "OCR", mute: "sin sonido" },
      hint: {
        idle: "Arrastra un archivo del escritorio", auto: "Mira, o toma tú un archivo",
        drag: "Ahora pulsa ⇧ Mayúsculas", dragTouch: "Sigue sosteniendo…",
        ring: "Suelta en una porción · ⇧ cambia de página", ringTouch: "Suelta en una porción",
        kbd: "Flechas eligen · Intro suelta · Esc cancela",
        busy: "Convirtiendo…", done: "¡Listo! Prueba con otro archivo"
      },
      smaller: "menos", clip: "Texto copiado al portapapeles", from: "de",
      show: "Mostrar en Finder", open: "Abrir", undo: "Deshacer"
    }
  };

  var current = "en";
  function T() { return UI[current]; }

  /* =====================================================================
     Icons and file artwork
     ===================================================================== */
  var IC = {
    img: '<rect x="2" y="3" width="12" height="10" rx="2"/><circle cx="6" cy="6.6" r="1.2"/><path d="M2.6 11.8l3.6-3.4 2.8 2.6 1.8-1.6 2.6 2.4"/>',
    doc: '<path d="M4 1.8h5.2L12.5 5v9.2H4z"/><path d="M9 1.8V5h3.4M6.2 8.4h4M6.2 11h4"/>',
    text: '<path d="M3 3.5h10M3 6.5h10M3 9.5h7M3 12.5h5"/>',
    gif: '<rect x="2.5" y="5.5" width="11" height="8" rx="1.6"/><path d="M4.5 3.5h7M6 1.8h4M8 7.6v3.8M6.1 9.5h3.8"/>',
    ico: '<rect x="3" y="3" width="10" height="10" rx="2.2" stroke-dasharray="2.2 1.8"/>',
    book: '<path d="M8 4.2C6.6 3.2 4.6 2.9 2.5 3.2v9.6c2.1-.3 4.1 0 5.5 1 1.4-1 3.4-1.3 5.5-1V3.2c-2.1-.3-4.1 0-5.5 1zM8 4.2v9.6"/>',
    film: '<rect x="2" y="3.5" width="9" height="9" rx="2"/><path d="M11 7l3-2v6l-3-2"/>',
    wave: '<path d="M2.5 7v2M5 5v6M7.5 2.8v10.4M10 5.2v5.6M12.5 6.4v3.2"/>',
    compress: '<path d="M2.5 2.5l4 4M6.5 3.4v3.1H3.4M13.5 13.5l-4-4M9.5 12.6V9.5h3.1"/>',
    resize: '<circle cx="7" cy="7" r="4.3"/><path d="M10.2 10.2l3.6 3.6M5.4 7h3.2M7 5.4v3.2"/>',
    crop: '<path d="M4.5 1.5v10h10M1.5 4.5h10v10"/>',
    rmbg: '<rect x="2" y="3" width="12" height="10.5" rx="2"/><circle cx="8" cy="7" r="1.9"/><path d="M4.8 13.4c.5-1.9 1.7-2.9 3.2-2.9s2.7 1 3.2 2.9"/>',
    gettext: '<path d="M2 5V3.5A1.5 1.5 0 013.5 2H5M11 2h1.5A1.5 1.5 0 0114 3.5V5M14 11v1.5a1.5 1.5 0 01-1.5 1.5H11M5 14H3.5A1.5 1.5 0 012 12.5V11M5 6h6M5 8.5h6M5 11h3.5"/>',
    rotate: '<path d="M3.2 9a5 5 0 109-3.6"/><path d="M12.6 2v3.6H9"/>',
    meta: '<path d="M13.5 2.5L2.8 7.2l4.6 1.4 1.4 4.6z"/><path d="M2.2 13.8L13.8 2.2"/>',
    addbg: '<rect x="1.8" y="4.2" width="10" height="8.6" rx="1.6"/><path d="M4.4 2.2h8.4a1.4 1.4 0 011.4 1.4v7"/>',
    split: '<rect x="3" y="1.8" width="10" height="5.2" rx="1.2"/><rect x="3" y="9" width="10" height="5.2" rx="1.2"/>',
    lock: '<rect x="3" y="7" width="10" height="7" rx="1.6"/><path d="M5.5 7V5a2.5 2.5 0 015 0v2"/>',
    mute: '<path d="M2.5 6h2.4L8.4 3v10L4.9 10H2.5z"/><path d="M11 6.2l3 3.6M14 6.2l-3 3.6"/>'
  };
  function icon(name) {
    return '<g fill="none" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round">' + (IC[name] || IC.doc) + "</g>";
  }

  var BADGE = { pdf: "#E5484D", docx: "#2F6BF2", md: "#6B6B78", txt: "#6B6B78", rtf: "#8A5CF6", html: "#E8762B", epub: "#2BA36B", m4a: "#F2557A", mov: "#5B5BD6", mp4: "#5B5BD6" };
  function fileSVG(ext) {
    ext = String(ext).toLowerCase();
    var isImg = /^(heic|jpg|png|avif|tiff|gif|ico)$/.test(ext);
    var isVid = /^(mov|mp4)$/.test(ext);
    var isAud = ext === "m4a";
    var s = '<svg viewBox="0 0 46 58" aria-hidden="true">' +
      '<path d="M7 1h22l16 16v36a4 4 0 0 1-4 4H7a4 4 0 0 1-4-4V5a4 4 0 0 1 4-4z" fill="#fff" stroke="rgba(0,0,0,.14)"/>' +
      '<path d="M29 1v12a4 4 0 0 0 4 4h12" fill="#EEE8E3" stroke="rgba(0,0,0,.12)"/>';
    if (isImg) {
      s += '<rect x="8" y="19" width="30" height="24" rx="2.5" fill="#FFBE84"/><circle cx="30" cy="26" r="3.4" fill="#FFF2CF"/>' +
        '<path d="M8 38.5l8-7.5 6.5 6 4.5-3.6L38 41v-.2 0a2.5 2.5 0 0 1-2.5 2.2h-25A2.5 2.5 0 0 1 8 40.5z" fill="#EA6482"/>' +
        '<path d="M15 43l10.5-8.6L38 43z" fill="#9273E6" opacity=".9"/>';
    } else if (isVid) {
      s += '<rect x="8" y="20" width="30" height="22" rx="2.5" fill="#3B3355"/><path d="M20 26v10l9-5z" fill="#fff"/>';
    } else if (isAud) {
      s += '<path d="M12 31v4M16 27v12M20 23v20M24 28v10M28 25v16M32 30v6" stroke="#F2557A" stroke-width="2.4" stroke-linecap="round"/>';
    } else {
      s += '<path d="M10 22h17M10 27h26M10 32h26M10 37h20" stroke="#CFC8C2" stroke-width="2.2" stroke-linecap="round"/>';
    }
    var col = BADGE[ext] || "#FF6B1F";
    var label = ext.toUpperCase();
    s += '<rect x="7" y="46" width="32" height="8.5" rx="2.6" fill="' + col + '"/>' +
      '<text x="23" y="52.6" text-anchor="middle" font-size="' + (label.length > 3 ? 5.6 : 6.2) + '" font-weight="800" fill="#fff" font-family="-apple-system,BlinkMacSystemFont,Inter,sans-serif" letter-spacing=".3">' + label + "</text></svg>";
    return s;
  }

  /* =====================================================================
     What each sample file can become
     [id, ring label, icon, output ext, size factor]
     ===================================================================== */
  var KINDS = {
    photo: { ext: "heic", size: 2.4e6,
      conv: [["jpg", "JPG", "img", "jpg", 0.2542], ["png", "PNG", "img", "png", 3.1], ["pdf", "PDF", "doc", "pdf", 0.26], ["avif", "AVIF", "img", "avif", 0.15], ["tiff", "TIFF", "img", "tiff", 6.2], ["gif", "GIF", "gif", "gif", 1.3], ["ico", "ICO", "ico", "ico", 0.03]],
      tools: [["compress", 0, "compress", "jpg", 0.25], ["resize", 0, "resize", "heic", 0.42], ["crop", 0, "crop", "heic", 0.7], ["rmbg", 0, "rmbg", "png", 1.9], ["text", 0, "gettext", null, 0], ["rotate", 0, "rotate", "heic", 1], ["meta", 0, "meta", "heic", 0.99], ["addbg", 0, "addbg", "png", 2.2]] },
    pdf: { ext: "pdf", size: 1.8e6,
      conv: [["jpg", "JPG", "img", "jpg", 0.42], ["png", "PNG", "img", "png", 1.6], ["tiff", "TIFF", "img", "tiff", 4.1], ["txt", "TXT", "text", "txt", 0.01], ["docx", "Word", "doc", "docx", 0.12], ["rtf", "RTF", "doc", "rtf", 0.05], ["html", "HTML", "text", "html", 0.08], ["epub", "EPUB", "book", "epub", 0.2]],
      tools: [["compress", 0, "compress", "pdf", 0.3], ["split", 0, "split", "pdf", 1.02], ["rotate", 0, "rotate", "pdf", 1], ["protect", 0, "lock", "pdf", 1.01], ["ocr", 0, "gettext", "pdf", 1.15]] },
    md: { ext: "md", size: 14e3,
      conv: [["pdf", "PDF", "doc", "pdf", 4.6], ["docx", "DOCX", "doc", "docx", 1.9], ["epub", "EPUB", "book", "epub", 2.3], ["txt", "TXT", "text", "txt", 0.95], ["rtf", "RTF", "doc", "rtf", 1.4], ["html", "HTML", "text", "html", 1.6]],
      tools: [] },
    mov: { ext: "mov", size: 48e6,
      conv: [["mp4", "MP4", "film", "mp4", 0.36], ["gif", "GIF", "gif", "gif", 0.22], ["m4a", "M4A", "wave", "m4a", 0.04]],
      tools: [["compress", 0, "compress", "mov", 0.18], ["mute", 0, "mute", "mov", 0.93]] }
  };
  var KIND_ICON = { photo: "img", pdf: "doc", md: "text", mov: "film" };

  function itemsFor(kind) {
    var k = KINDS[kind], t = T();
    return [
      k.conv.map(function (c) { return { id: c[0], label: c[1], icon: c[2], ext: c[3], f: c[4], tool: false }; }),
      k.tools.map(function (c) { return { id: c[0], label: t.tl[c[0]], icon: c[2], ext: c[3], f: c[4], tool: true }; })
    ];
  }

  function fmtSize(b) {
    var s = b >= 1e6 ? (b / 1e6).toFixed(1) + " MB" : Math.max(1, Math.round(b / 1e3)) + " KB";
    return current === "es" ? s.replace(".", ",") : s;
  }

  /* =====================================================================
     The ring
     ===================================================================== */
  var ringCount = 0;
  var GEO = { R: 140, r: 68, hub: 62, mid: 104, sw: 10, gap: 8.5 };

  function pol(rad, deg) {
    var a = (deg - 90) * Math.PI / 180;
    return [rad * Math.cos(a), rad * Math.sin(a)];
  }
  function f2(p) { return p[0].toFixed(2) + " " + p[1].toFixed(2); }
  function slicePath(a0, a1) {
    var R = GEO.R - GEO.sw / 2, r = GEO.r + GEO.sw / 2;
    var go = GEO.gap / R * 180 / Math.PI, gi = GEO.gap / r * 180 / Math.PI;
    var o0 = pol(R, a0 + go), o1 = pol(R, a1 - go), i1 = pol(r, a1 - gi), i0 = pol(r, a0 + gi);
    var lg = (a1 - a0) > 180 ? 1 : 0;
    return "M" + f2(o0) + " A" + R + " " + R + " 0 " + lg + " 1 " + f2(o1) +
      " L" + f2(i1) + " A" + r + " " + r + " 0 " + lg + " 0 " + f2(i0) + " Z";
  }

  function Ring(host) {
    var id = "kr" + (++ringCount);
    var el = document.createElement("div");
    el.className = "kring";
    el.innerHTML =
      '<div class="kring-disc"></div>' +
      '<svg viewBox="-150 -150 300 300" aria-hidden="true">' +
        '<defs><linearGradient id="' + id + 'g" x1="0" y1="0" x2="1" y2="1"><stop offset="0" stop-color="#FFB03A"/><stop offset="1" stop-color="#FF5E1A"/></linearGradient></defs>' +
        '<g class="kr-slices"></g>' +
        '<g class="kr-hub">' +
          '<circle class="kr-hub-bg" r="' + GEO.hub + '"/>' +
          '<circle class="kr-hub-ring" r="' + (GEO.hub - 1.5) + '"/>' +
          '<circle class="kr-prog" r="' + (GEO.hub - 1.5) + '" transform="rotate(-90)" pathLength="100" stroke-dasharray="100" stroke-dashoffset="100"/>' +
          '<g class="kr-hub-c"><g class="kr-hub-ico" transform="translate(-12 -30) scale(1.5)"></g><text class="kr-hub-t" y="17" text-anchor="middle"></text></g>' +
          '<g class="kr-done"><circle r="' + GEO.hub + '" fill="url(#' + id + 'g)"/><path d="M-17 1l11 11 23-25" fill="none" stroke="#fff" stroke-width="7" stroke-linecap="round" stroke-linejoin="round" pathLength="60"/></g>' +
        "</g>" +
      "</svg>" +
      '<div class="kring-pill"><span class="kk">⇧</span><span class="p0"></span><span class="p1"></span></div>';
    host.appendChild(el);

    var gSlices = $(".kr-slices", el), hubIco = $(".kr-hub-ico", el), hubT = $(".kr-hub-t", el), prog = $(".kr-prog", el);
    var pill = $(".kring-pill", el), p0 = $(".p0", el), p1 = $(".p1", el);
    var nodes = [];
    var api = { el: el, pill: pill, page: 0, hl: -1, items: [[], []], idle: { icon: "img", label: "" } };

    function render() {
      var list = api.items[api.page] || [];
      var n = list.length, step = 360 / Math.max(1, n);
      gSlices.innerHTML = "";
      nodes = [];
      list.forEach(function (it, i) {
        var a0 = i * step - step / 2, a1 = a0 + step;
        var g = document.createElementNS("http://www.w3.org/2000/svg", "g");
        g.setAttribute("class", "kr-s");
        var lp = pol(GEO.mid, i * step);
        var len = it.label.length;
        var fs = len > 9 ? 8.2 : len > 7 ? 9.2 : 10.5;
        g.innerHTML = '<path d="' + slicePath(a0, a1) + '"/>' +
          '<g class="kr-ico" transform="translate(' + (lp[0] - 8.8).toFixed(1) + " " + (lp[1] - 19).toFixed(1) + ') scale(1.1)">' + icon(it.icon) + "</g>" +
          '<text x="' + lp[0].toFixed(1) + '" y="' + (lp[1] + 10).toFixed(1) + '" text-anchor="middle" style="font-size:' + fs + 'px">' + it.label + "</text>";
        gSlices.appendChild(g);
        var off = pol(5, i * step);
        nodes.push({ g: g, path: g.firstChild, off: off });
      });
      p0.textContent = T().convert;
      p1.textContent = T().tools;
      p0.className = "p0" + (api.page === 0 ? " on" : "");
      p1.className = "p1" + (api.page === 1 ? " on" : "");
      p1.style.opacity = api.items[1].length ? "" : ".4";
      paint();
    }

    function paint() {
      var list = api.items[api.page] || [];
      nodes.forEach(function (nd, i) {
        var on = i === api.hl;
        nd.g.setAttribute("class", "kr-s" + (on ? " on" : ""));
        nd.g.style.transform = on ? "translate(" + nd.off[0].toFixed(2) + "px," + nd.off[1].toFixed(2) + "px)" : "";
        nd.path.style.fill = on ? "url(#" + id + "g)" : "";
        nd.path.style.stroke = on ? "url(#" + id + "g)" : "";
      });
      var it = api.hl >= 0 ? list[api.hl] : null;
      el.classList.toggle("has-hl", !!it);
      hubIco.innerHTML = icon(it ? it.icon : api.idle.icon);
      hubT.textContent = it ? it.label : api.idle.label;
      var hl = it ? it.label.length : api.idle.label.length;
      hubT.style.fontSize = hl > 11 ? "10.5px" : hl > 8 ? "11.5px" : "";
    }

    api.set = function (items, idle) {
      api.items = items; api.idle = idle || api.idle; api.page = 0; api.hl = -1; render();
    };
    api.relabel = function (items, idle) {
      api.items = items; if (idle) api.idle = idle; render();
    };
    api.current = function () { return api.hl >= 0 ? api.items[api.page][api.hl] : null; };
    api.highlight = function (i) { if (i !== api.hl) { api.hl = i; paint(); } };
    api.count = function () { return (api.items[api.page] || []).length; };
    api.toggle = function () {
      pill.classList.add("press");
      setTimeout(function () { pill.classList.remove("press"); }, 160);
      if (!api.items[1 - api.page].length) {
        el.classList.remove("shake"); void el.offsetWidth; el.classList.add("shake");
        return false;
      }
      var next = 1 - api.page;
      if (reduce) { api.page = next; api.hl = -1; render(); return true; }
      gSlices.classList.add("flip");
      setTimeout(function () {
        api.page = next; api.hl = -1; render();
        gSlices.classList.remove("flip");
      }, 170);
      return true;
    };
    api.setPage = function (p) { api.page = p; api.hl = -1; render(); };
    api.size = function () { return el.offsetWidth || 300; };
    api.hit = function (dx, dy) {
      var sc = api.size() / 300, d = Math.sqrt(dx * dx + dy * dy) / sc;
      if (d < GEO.r - 2) return -1;
      if (d > 162) return -2;
      var n = api.count(); if (!n) return -1;
      var step = 360 / n;
      var ang = (Math.atan2(dx, -dy) * 180 / Math.PI + 360) % 360;
      return Math.floor(((ang + step / 2) % 360) / step);
    };
    api.sliceCenter = function (i) {
      var sc = api.size() / 300, step = 360 / Math.max(1, api.count());
      var p = pol(GEO.mid * sc, i * step);
      return { x: p[0], y: p[1] };
    };
    api.progress = function (ms) {
      el.classList.add("busy");
      prog.style.transition = "none";
      prog.style.strokeDashoffset = "100";
      void prog.getBoundingClientRect();
      prog.style.transition = "stroke-dashoffset " + ms + "ms cubic-bezier(.45,.05,.35,1)";
      prog.style.strokeDashoffset = "0";
      return new Promise(function (res) { setTimeout(res, reduce ? 0 : ms); });
    };
    api.done = function () { el.classList.add("done"); };
    api.reset = function () {
      el.classList.remove("busy", "done", "shake");
      prog.style.transition = "none";
      prog.style.strokeDashoffset = "100";
      api.hl = -1; paint();
    };
    return api;
  }

  /* =====================================================================
     Hero demo: a tiny Mac desktop
     ===================================================================== */
  var Demo = (function () {
    var stage = $("#demo");
    if (!stage) return null;
    var tilt = $("#demo-tilt");
    var filesBox = $("#demo-files"), ghost = $("#demo-ghost"), toast = $("#demo-toast");
    var cursor = $("#demo-cursor"), key = $("#demo-key"), hintText = $("#demo-hint-text");
    var ringHost = $("#demo-ring");
    var ring = Ring(ringHost);
    var ORDER = ["photo", "pdf", "md", "mov"];
    var S = { state: "idle", mode: null, kind: null, file: null, x: 0, y: 0, sx: 0, sy: 0, cx: 0, cy: 0, touch: false, gen: null, seq: 0 };
    var timers = { open: 0, toast: 0, resume: 0, hint: 0 };
    var auto = { on: false, token: 0 };
    var inView = false, userTouched = false;

    function W() { return stage.clientWidth; }
    function H() { return stage.clientHeight; }
    function local(e) { var r = stage.getBoundingClientRect(); return { x: e.clientX - r.left, y: e.clientY - r.top }; }
    function fileEl(kind) { return $('.dfile[data-kind="' + kind + '"]', filesBox); }
    function fileCenter(el) {
      var r = el.getBoundingClientRect(), s = stage.getBoundingClientRect();
      return { x: r.left - s.left + r.width / 2, y: r.top - s.top + 35 };
    }

    function renderFiles() {
      var t = T();
      filesBox.innerHTML = ORDER.map(function (k) {
        var name = t.base[k] + "." + KINDS[k].ext;
        return '<div class="frow"><div class="dfile" role="button" tabindex="0" data-kind="' + k + '" aria-label="' + name + '">' +
          fileSVG(KINDS[k].ext) + '<span class="fname">' + name + "</span></div></div>";
      }).join("");
      S.gen = null;
    }

    function hint(k) {
      var t = T().hint;
      hintText.textContent = t[k] || t.idle;
      key.classList.toggle("pulse", k === "drag");
    }
    function pressKey() {
      key.classList.add("press");
      setTimeout(function () { key.classList.remove("press"); }, 220);
    }

    function setPointer(x, y) {
      S.x = x; S.y = y;
      cursor.style.transform = "translate(" + x + "px," + y + "px)";
      if (S.state === "pressed" && Math.hypot(x - S.sx, y - S.sy) > 6) beginDrag();
      if (S.state === "drag" || S.state === "ring") {
        ghost.style.transform = "translate(" + (x - 23) + "px," + (y - 29) + "px)";
      }
      if (S.state === "ring" && S.mode !== "kbd") {
        var h = ring.hit(x - S.cx, y - S.cy);
        ring.highlight(h >= 0 ? h : -1);
      }
    }

    function press(el, x, y, mode) {
      clearGen();
      hideToast();
      S.file = el; S.kind = el.getAttribute("data-kind"); S.mode = mode;
      S.sx = x; S.sy = y; S.state = "pressed";
      $$(".dfile.sel", filesBox).forEach(function (f) { f.classList.remove("sel"); });
      el.classList.add("sel");
      var k = KINDS[S.kind];
      ring.set(itemsFor(S.kind), { icon: KIND_ICON[S.kind], label: k.ext.toUpperCase() });
      setPointer(x, y);
    }

    function beginDrag() {
      S.state = "drag";
      ghost.classList.remove("fly");
      ghost.innerHTML = fileSVG(KINDS[S.kind].ext) + '<span class="plus">+</span>';
      ghost.style.opacity = "";
      ghost.style.transform = "translate(" + (S.x - 23) + "px," + (S.y - 29) + "px)";
      ghost.classList.add("on");
      S.file.classList.add("lifted");
      if (S.mode === "user") {
        hint(S.touch ? "dragTouch" : "drag");
        clearTimeout(timers.open);
        timers.open = setTimeout(function () { if (S.state === "drag") { pressKey(); openRing(); } }, S.touch ? 280 : 2200);
      }
    }

    function ringSize() {
      var w = W(), h = H();
      var d = Math.min(330, w - 24, h - 96);
      return Math.max(200, Math.min(d, Math.max(w * 0.5, 250)));
    }

    function openRing() {
      clearTimeout(timers.open);
      var d = ringSize(), w = W(), h = H();
      ring.el.style.setProperty("--d", d + "px");
      S.cx = clamp(S.x, d / 2 + 10, w - d / 2 - 10);
      S.cy = clamp(S.y, d / 2 + 36, h - d / 2 - 52);
      ringHost.style.left = S.cx + "px";
      ringHost.style.top = S.cy + "px";
      ring.reset();
      ring.setPage(0);
      ring.el.classList.remove("closing");
      void ring.el.offsetWidth;
      ring.el.classList.add("open");
      S.state = "ring";
      if (S.mode === "user") hint(S.touch ? "ringTouch" : "ring");
      if (S.mode === "kbd") { hint("kbd"); ring.highlight(0); }
      setPointer(S.x, S.y);
    }

    function closeRing() {
      if (!ring.el.classList.contains("open")) return;
      ring.el.classList.remove("open");
      ring.el.classList.add("closing");
      setTimeout(function () { ring.el.classList.remove("closing"); ring.reset(); }, 320);
    }

    function shift() {
      pressKey();
      if (S.state === "drag") openRing();
      else if (S.state === "ring") {
        ring.toggle();
        setTimeout(function () {
          if (S.mode === "kbd") ring.highlight(0); else setPointer(S.x, S.y);
        }, 200);
      }
    }

    function flyGhostTo(x, y, scale) {
      ghost.classList.add("fly");
      ghost.style.transform = "translate(" + (x - 23) + "px," + (y - 29) + "px) scale(" + scale + ")";
      ghost.style.opacity = "0";
      setTimeout(function () { ghost.classList.remove("on", "fly"); ghost.style.opacity = ""; }, 460);
    }

    function cancel() {
      clearTimeout(timers.open);
      if (S.state === "idle") return;
      var was = S.state;
      closeRing();
      if (S.file && (was === "drag" || was === "ring")) {
        var p = fileCenter(S.file);
        flyGhostTo(p.x, p.y, 1);
      } else {
        ghost.classList.remove("on");
      }
      if (S.file) { S.file.classList.remove("lifted"); }
      S.state = "idle";
      if (S.mode !== "auto") hint("idle");
    }

    function release() {
      clearTimeout(timers.open);
      if (S.state === "ring" && ring.hl >= 0) return convert();
      cancel();
      return Promise.resolve();
    }

    function convert() {
      var item = ring.current();
      var seq = S.seq;
      S.state = "busy";
      var c = ring.sliceCenter(ring.hl);
      flyGhostTo(S.cx + c.x, S.cy + c.y, 0.3);
      if (S.mode !== "auto") hint("busy");
      return ring.progress(item.tool ? 1100 : 900).then(function () {
        ring.done();
        return wait(560);
      }).then(function () {
        if (seq !== S.seq) return;
        closeRing();
        if (S.file) S.file.classList.remove("lifted");
        showResult(item);
        S.state = "idle";
        if (S.mode !== "auto") {
          hint("done");
          clearTimeout(timers.toast);
          timers.toast = setTimeout(function () { hideToast(); hint("idle"); }, 5200);
          scheduleResume();
        }
      });
    }

    function clearGen() {
      if (S.gen) {
        var g = S.gen; S.gen = null;
        g.classList.add("out");
        setTimeout(function () { if (g.parentNode) g.parentNode.removeChild(g); }, 300);
      }
    }

    function showResult(item) {
      var t = T(), k = KINDS[S.kind];
      var base = t.base[S.kind];
      var name, ext = item.ext, sub;
      var inExt = k.ext.toUpperCase();
      if (!ext) {
        name = t.clip;
        sub = t.tl[item.id] + " · " + base + "." + k.ext;
      } else {
        var out = k.size * item.f;
        name = item.tool ? base + " " + t.sfx[item.id] + "." + ext : base + "." + ext;
        var arrow = item.tool ? t.tl[item.id] : inExt + " → " + item.label;
        sub = arrow + " · " + fmtSize(k.size) + " → " + fmtSize(out);
        if (out < k.size * 0.9) sub += " · " + Math.round((1 - out / k.size) * 100) + (current === "es" ? " % " : "% ") + t.smaller;
        // the new file appears next to the original
        var row = S.file.parentNode;
        var g = document.createElement("div");
        g.className = "dfile gen";
        g.innerHTML = fileSVG(ext) + '<span class="fname">' + name + "</span>";
        row.insertBefore(g, S.file);
        S.gen = g;
      }
      toast.innerHTML =
        '<div class="t-ico">' + fileSVG(ext || k.ext) + '<span class="ok"><svg viewBox="0 0 10 10"><path d="M2 5.2l2 2 4-4.4" fill="none" stroke="#fff" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"/></svg></span></div>' +
        "<div><b>" + name + '</b><div class="t-sub">' + sub + "</div>" +
        (ext ? '<div class="t-btns"><button type="button" class="primary" data-a="show">' + t.show + '</button><button type="button" data-a="open">' + t.open + '</button><button type="button" data-a="undo">' + t.undo + "</button></div>" : "") +
        "</div>";
      void toast.offsetWidth;
      toast.classList.add("on");
    }
    function hideToast() { clearTimeout(timers.toast); toast.classList.remove("on"); }

    toast.addEventListener("click", function (e) {
      var b = e.target.closest("button"); if (!b) return;
      var a = b.getAttribute("data-a");
      if (a === "undo") { clearGen(); hideToast(); hint("idle"); }
      else if (S.gen) { S.gen.classList.remove("bounce"); void S.gen.offsetWidth; S.gen.classList.add("bounce"); }
    });

    function resetScene() {
      clearTimeout(timers.open); clearTimeout(timers.toast);
      ring.el.classList.remove("open", "closing"); ring.reset();
      ghost.classList.remove("on", "fly"); ghost.style.opacity = "";
      $$(".dfile", filesBox).forEach(function (f) { f.classList.remove("sel", "lifted"); });
      hideToast();
      if (S.gen && S.gen.parentNode) S.gen.parentNode.removeChild(S.gen);
      S.gen = null;
      S.state = "idle";
      S.seq++;
    }

    /* ---- user input ---- */
    function lockTilt() { userTouched = true; if (tilt) { tilt.style.setProperty("--tilt", "0deg"); } }

    filesBox.addEventListener("pointerdown", function (e) {
      var el = e.target.closest(".dfile");
      if (!el || el.classList.contains("gen") || e.button > 0) return;
      e.preventDefault();
      lockTilt();
      stopAuto(); resetScene();
      clearTimeout(timers.resume);
      S.touch = e.pointerType !== "mouse";
      cursor.classList.remove("on");
      var p = local(e);
      press(el, p.x, p.y, "user");
      stage.classList.add("grabbing");
      window.addEventListener("pointermove", onMove);
      window.addEventListener("pointerup", onUp);
      window.addEventListener("pointercancel", onCancel);
    });
    function onMove(e) { var p = local(e); setPointer(p.x, p.y); }
    function detach() {
      stage.classList.remove("grabbing");
      window.removeEventListener("pointermove", onMove);
      window.removeEventListener("pointerup", onUp);
      window.removeEventListener("pointercancel", onCancel);
    }
    function onUp(e) {
      detach();
      var p = local(e); setPointer(p.x, p.y);
      if (S.state === "pressed") { S.state = "idle"; hint("idle"); scheduleResume(); return; }
      release().then(scheduleResume);
    }
    function onCancel() { detach(); cancel(); scheduleResume(); }

    // pill toggles pages with a tap (useful on touch screens)
    ring.pill.addEventListener("pointerdown", function (e) {
      if (S.state === "ring") { e.preventDefault(); e.stopPropagation(); shift(); }
    });

    // keyboard: focus a file, Enter opens the ring
    filesBox.addEventListener("keydown", function (e) {
      var el = e.target.closest(".dfile");
      if (!el || el.classList.contains("gen")) return;
      if ((e.key === "Enter" || e.key === " ") && S.state === "idle") {
        e.preventDefault();
        lockTilt(); stopAuto(); resetScene(); clearTimeout(timers.resume);
        var p = fileCenter(el);
        press(el, p.x, p.y, "kbd");
        beginDrag();
        setPointer(p.x - 40, p.y + 20);
        openRing();
      }
    });
    document.addEventListener("keydown", function (e) {
      if (S.mode !== "kbd" || S.state !== "ring") return;
      var n = ring.count();
      if (e.key === "ArrowRight" || e.key === "ArrowDown") { e.preventDefault(); ring.highlight((ring.hl + 1) % n); }
      else if (e.key === "ArrowLeft" || e.key === "ArrowUp") { e.preventDefault(); ring.highlight((ring.hl - 1 + n) % n); }
      else if (e.key === "Enter") { e.preventDefault(); convert(); }
      else if (e.key === "Escape") { e.preventDefault(); cancel(); }
    });

    /* ---- autoplay ---- */
    function wait(ms) { return new Promise(function (r) { setTimeout(r, ms); }); }
    function step(ms, tok) {
      return wait(ms).then(function () { if (tok !== auto.token) throw "stop"; });
    }
    function ease(t) { return t < 0.5 ? 4 * t * t * t : 1 - Math.pow(-2 * t + 2, 3) / 2; }
    function tween(x1, y1, ms, tok) {
      var x0 = S.x, y0 = S.y, t0 = performance.now();
      return new Promise(function (res, rej) {
        (function frame(now) {
          if (tok !== auto.token) return rej("stop");
          var t = Math.min(1, (now - t0) / ms), e = ease(t);
          setPointer(x0 + (x1 - x0) * e, y0 + (y1 - y0) * e);
          if (t < 1) requestAnimationFrame(frame); else res();
        })(t0);
      });
    }

    var SCENES = [
      { kind: "photo", page: 0, target: "jpg" },
      { kind: "pdf", page: 1, target: "compress" },
      { kind: "mov", page: 0, target: "gif" }
    ];

    function scene(sc, tok) {
      var f = fileEl(sc.kind), p = fileCenter(f);
      var w = W(), h = H();
      S.touch = false;
      setPointer(w * 0.3, h * 0.62);
      cursor.classList.add("on");
      return step(500, tok)
        .then(function () { return tween(p.x, p.y, 900, tok); })
        .then(function () { return step(250, tok); })
        .then(function () { press(f, p.x, p.y, "auto"); return tween(p.x - Math.max(60, w * 0.3), p.y + 30, 750, tok); })
        .then(function () { return step(350, tok); })
        .then(function () { shift(); return step(sc.page ? 750 : 450, tok); })
        .then(function () { if (sc.page) { shift(); return step(650, tok); } })
        .then(function () {
          var idx = 0;
          ring.items[ring.page].forEach(function (it, i) { if (it.id === sc.target) idx = i; });
          var c = ring.sliceCenter(idx);
          return tween(S.cx + c.x * 0.96, S.cy + c.y * 0.96, 850, tok);
        })
        .then(function () { return step(500, tok); })
        .then(function () { return release(); })
        .then(function () { return step(2800, tok); })
        .then(function () { hideToast(); return tween(w * 0.25, h * 0.7, 700, tok); })
        .then(function () { cursor.classList.remove("on"); return step(700, tok); })
        .then(function () { clearGen(); $$(".dfile.sel", filesBox).forEach(function (x) { x.classList.remove("sel"); }); return step(500, tok); });
    }

    function startAuto() {
      if (reduce || auto.on || !inView || S.state !== "idle" || document.hidden) return;
      auto.on = true;
      var tok = ++auto.token, i = 0;
      hint("auto");
      (function loop() {
        scene(SCENES[i % SCENES.length], tok).then(function () { i++; loop(); }).catch(function () {});
      })();
    }
    function stopAuto() {
      if (!auto.on) return;
      auto.on = false; auto.token++;
      cursor.classList.remove("on");
      resetScene();
      hint("idle");
    }
    function scheduleResume() {
      clearTimeout(timers.resume);
      timers.resume = setTimeout(function () { if (S.state === "idle") { resetScene(); startAuto(); } }, 9000);
    }

    if ("IntersectionObserver" in window) {
      new IntersectionObserver(function (es) {
        es.forEach(function (en) {
          inView = en.isIntersecting;
          if (inView) startAuto(); else stopAuto();
        });
      }, { threshold: 0.35 }).observe(stage);
    }
    document.addEventListener("visibilitychange", function () { if (document.hidden) stopAuto(); else startAuto(); });

    // Static end state when motion is reduced: ring open over the photo, JPG highlighted.
    function staticFrame() {
      var f = fileEl("photo"); if (!f) return;
      var p = fileCenter(f);
      press(f, p.x, p.y, "auto");
      S.state = "drag";
      S.x = p.x - Math.max(60, W() * 0.3); S.y = p.y + 30;
      openRing();
      ring.highlight(0);
      ghost.classList.remove("on");
      f.classList.remove("lifted");
      S.state = "idle";
      hint("idle");
    }

    function relang() {
      var wasAuto = auto.on;
      stopAuto(); resetScene(); renderFiles(); hint("idle");
      if (reduce) staticFrame();
      else if (wasAuto) startAuto();
    }

    renderFiles();
    hint("idle");
    if (reduce) requestAnimationFrame(staticFrame);

    return {
      relang: relang,
      active: function () { return (S.mode === "user" || S.mode === "kbd") && (S.state === "drag" || S.state === "ring"); },
      shift: shift,
      touched: function () { return userTouched; }
    };
  })();

  /* =====================================================================
     Explorer ring in "Convert it. Or fix it."
     ===================================================================== */
  var Explorer = (function () {
    var host = $("#ex-ring"), box = $("#ex-files");
    if (!host || !box) return null;
    var ring = Ring(host);
    var kinds = ["photo", "pdf", "mov", "md"];
    var kind = "photo", hovering = false, busy = false, inView = false, timer = 0, ticks = 0;

    function renderButtons() {
      box.innerHTML = kinds.map(function (k) {
        return '<button type="button" role="radio" aria-checked="' + (k === kind) + '" data-k="' + k + '">' +
          fileSVG(KINDS[k].ext) + "<span>" + T().ex[k] + "</span></button>";
      }).join("");
    }
    function load(k, keepPage) {
      kind = k;
      var page = keepPage ? ring.page : 0;
      ring.set(itemsFor(k), { icon: KIND_ICON[k], label: T().base[k] + "." + KINDS[k].ext });
      if (page && ring.items[1].length) ring.setPage(1);
      ticks = 0;
      $$("button", box).forEach(function (b) { b.setAttribute("aria-checked", b.getAttribute("data-k") === k ? "true" : "false"); });
    }
    box.addEventListener("click", function (e) {
      var b = e.target.closest("button"); if (!b) return;
      load(b.getAttribute("data-k"));
    });
    box.addEventListener("keydown", function (e) {
      if (e.key !== "ArrowRight" && e.key !== "ArrowLeft") return;
      var i = kinds.indexOf(kind) + (e.key === "ArrowRight" ? 1 : -1);
      i = (i + kinds.length) % kinds.length;
      load(kinds[i]);
      $('button[data-k="' + kinds[i] + '"]', box).focus();
    });

    function rel(e) {
      var r = ring.el.getBoundingClientRect();
      return { x: e.clientX - (r.left + r.width / 2), y: e.clientY - (r.top + r.height / 2) };
    }
    ring.el.addEventListener("pointermove", function (e) {
      if (busy) return;
      hovering = true;
      var p = rel(e), h = ring.hit(p.x, p.y);
      ring.highlight(h >= 0 ? h : -1);
    });
    ring.el.addEventListener("pointerleave", function () { hovering = false; });
    ring.el.addEventListener("click", function (e) {
      if (busy || e.target.closest(".kring-pill")) return;
      var p = rel(e), h = ring.hit(p.x, p.y);
      if (h < 0) return;
      ring.highlight(h);
      busy = true;
      ring.progress(700).then(function () { ring.done(); return new Promise(function (r) { setTimeout(r, 900); }); })
        .then(function () { ring.reset(); ring.highlight(h); busy = false; });
    });
    ring.pill.addEventListener("click", function () { toggle(); });

    function toggle() { if (!busy) { ring.toggle(); ticks = 0; } }

    function tick() {
      if (hovering || busy || document.hidden) return;
      var n = ring.count();
      if (!n) return;
      ticks++;
      if (ring.hl >= n - 1 && ring.items[1 - ring.page].length) { ring.toggle(); ticks = 0; return; }
      ring.highlight((ring.hl + 1) % n);
    }
    function start() { if (!timer && !reduce) timer = setInterval(tick, 1300); }
    function stop() { clearInterval(timer); timer = 0; }
    if ("IntersectionObserver" in window) {
      new IntersectionObserver(function (es) {
        es.forEach(function (en) { inView = en.isIntersecting; if (inView) start(); else stop(); });
      }, { threshold: 0.3 }).observe(host);
    }

    renderButtons();
    load("photo");
    if (reduce) ring.highlight(0);

    return {
      inView: function () { return inView; },
      toggle: toggle,
      relang: function () { renderButtons(); load(kind, true); }
    };
  })();

  // Shift anywhere on the page: drives the demo while dragging, otherwise flips the visible ring.
  document.addEventListener("keydown", function (e) {
    if (e.key !== "Shift" || e.repeat) return;
    var tag = (e.target && e.target.tagName) || "";
    if (/INPUT|TEXTAREA|SELECT/.test(tag) || (e.target && e.target.isContentEditable)) return;
    if (Demo && Demo.active()) { Demo.shift(); return; }
    if (Explorer && Explorer.inView()) Explorer.toggle();
  });

  /* =====================================================================
     Themes carousel (cropped from assets/themes.jpg)
     ===================================================================== */
  (function () {
    var track = $("#themes-track"), dots = $("#themes-dots");
    if (!track) return;
    var X = [9.81, 36.58, 63.29, 90.0], Y = [28.87, 87.97];
    var THEMES = [
      ["Kumquat", 0, 0, "#FF7A22"], ["Ocean", 1, 0, "#3B6CF0"], ["Grape", 2, 0, "#9C6CF4"], ["Mint", 3, 0, "#1DB98A"],
      ["Rosé", 0, 1, "#E6407A"], ["Lemon", 1, 1, "#F7B21E"], ["Sunset", 2, 1, "#F25F6C"], ["Graphite", 3, 1, "#6B7280"]
    ];
    track.innerHTML = THEMES.map(function (t) {
      return '<figure class="theme-card"><div class="theme-crop" role="img" aria-label="' + t[0] + '" style="background-position:' + X[t[1]] + "% " + Y[t[2]] + '%"></div>' +
        '<figcaption><span>' + t[0] + '</span><i style="background:' + t[3] + '"></i></figcaption></figure>';
    }).join("");
    dots.innerHTML = THEMES.map(function () { return "<i></i>"; }).join("");
    var dotEls = $$("i", dots);
    function stepW() { var c = track.firstElementChild; return c ? c.offsetWidth + 16 : 300; }
    function update() {
      var max = track.scrollWidth - track.clientWidth;
      var i = track.scrollLeft >= max - 4 ? THEMES.length - 1 : Math.round(track.scrollLeft / stepW());
      dotEls.forEach(function (d, j) { d.classList.toggle("on", j === i); });
    }
    track.addEventListener("scroll", function () { requestAnimationFrame(update); }, { passive: true });
    $("#th-prev").addEventListener("click", function () { track.scrollBy({ left: -stepW(), behavior: reduce ? "auto" : "smooth" }); });
    $("#th-next").addEventListener("click", function () {
      var max = track.scrollWidth - track.clientWidth;
      if (track.scrollLeft >= max - 4) track.scrollTo({ left: 0, behavior: reduce ? "auto" : "smooth" });
      else track.scrollBy({ left: stepW(), behavior: reduce ? "auto" : "smooth" });
    });
    update();
  })();

  /* =====================================================================
     Screenshot tabs
     ===================================================================== */
  $$(".shot-tabs [role=tab]").forEach(function (tab) {
    tab.addEventListener("click", function () {
      var n = tab.getAttribute("data-shot");
      $$(".shot-tabs [role=tab]").forEach(function (t) { t.setAttribute("aria-selected", t === tab ? "true" : "false"); });
      $$(".shot-frame .shot").forEach(function (img) { img.classList.toggle("on", img.id === "shot-" + n); });
    });
  });

  /* =====================================================================
     Marquee
     ===================================================================== */
  $$(".mq-track").forEach(function (tr) {
    var words = tr.getAttribute("data-mq").split(" ");
    var a = words.map(function (w) { return "<span>" + w + "</span>"; }).join("");
    var b = words.map(function (w) { return '<span aria-hidden="true">' + w + "</span>"; }).join("");
    tr.innerHTML = a + b;
  });

  /* =====================================================================
     Scroll reveal, header, demo tilt, terminal typing
     ===================================================================== */
  $$("[data-stagger]").forEach(function (box) {
    $$(".reveal", box).forEach(function (el, i) { el.style.setProperty("--d", Math.min(i, 6) * 0.07 + "s"); });
  });
  if ("IntersectionObserver" in window && !reduce) {
    var io = new IntersectionObserver(function (es) {
      es.forEach(function (en) { if (en.isIntersecting) { en.target.classList.add("in"); io.unobserve(en.target); } });
    }, { threshold: 0.12, rootMargin: "0px 0px -6% 0px" });
    $$(".reveal").forEach(function (el) { io.observe(el); });
  } else {
    $$(".reveal").forEach(function (el) { el.classList.add("in"); });
  }

  var header = $("#site-header"), tiltEl = $("#demo-tilt");
  var ticking = false;
  function onScroll() {
    ticking = false;
    header.classList.toggle("scrolled", window.scrollY > 8);
    if (tiltEl && !reduce && !(Demo && Demo.touched())) {
      var r = tiltEl.getBoundingClientRect(), vh = window.innerHeight;
      var p = clamp((vh - r.top) / (vh * 0.55), 0, 1);
      tiltEl.style.setProperty("--tilt", ((1 - p) * 14).toFixed(2) + "deg");
    }
  }
  window.addEventListener("scroll", function () { if (!ticking) { ticking = true; requestAnimationFrame(onScroll); } }, { passive: true });
  window.addEventListener("resize", onScroll);
  onScroll();

  (function () {
    var el = $("#typed"); if (!el || reduce || !("IntersectionObserver" in window)) return;
    var full = el.textContent; el.textContent = "";
    var o = new IntersectionObserver(function (es) {
      if (!es[0].isIntersecting) return;
      o.disconnect();
      var i = 0;
      (function type() { el.textContent = full.slice(0, ++i); if (i < full.length) setTimeout(type, 38 + Math.random() * 50); })();
    }, { threshold: 0.6 });
    o.observe(el);
  })();

  /* =====================================================================
     Clock in the fake menu bar
     ===================================================================== */
  function tickClock() {
    var c = $("#demo-clock"); if (!c) return;
    try {
      c.textContent = new Intl.DateTimeFormat(current === "es" ? "es-ES" : "en-US", { weekday: "short", hour: "numeric", minute: "2-digit" }).format(new Date());
    } catch (e) {}
  }
  setInterval(tickClock, 30000);

  /* =====================================================================
     Copy buttons
     ===================================================================== */
  function copyText(text) {
    if (navigator.clipboard && window.isSecureContext) return navigator.clipboard.writeText(text);
    return new Promise(function (resolve, reject) {
      var ta = document.createElement("textarea");
      ta.value = text; ta.setAttribute("readonly", "");
      ta.style.position = "fixed"; ta.style.opacity = "0";
      document.body.appendChild(ta); ta.select();
      try { document.execCommand("copy") ? resolve() : reject(); } catch (e) { reject(e); }
      document.body.removeChild(ta);
    });
  }
  $$(".copy").forEach(function (btn) {
    var timer;
    btn.addEventListener("click", function () {
      copyText(btn.getAttribute("data-copy")).then(function () {
        btn.classList.add("done");
        btn.querySelector(".copy-label").textContent = T().copied;
        clearTimeout(timer);
        timer = setTimeout(function () {
          btn.classList.remove("done");
          btn.querySelector(".copy-label").textContent = T().copy;
        }, 1800);
      }).catch(function () {});
    });
  });

  /* =====================================================================
     Language switching
     ===================================================================== */
  var textNodes = $$("[data-i18n]");
  var attrNodes = $$("[data-i18n-attr]");
  var EN = {};
  textNodes.forEach(function (n) { var k = n.getAttribute("data-i18n"); if (!(k in EN)) EN[k] = n.innerHTML; });
  attrNodes.forEach(function (n) {
    n.getAttribute("data-i18n-attr").split(";").forEach(function (pair) {
      var p = pair.split(":"); if (!(p[1] in EN)) EN[p[1]] = n.getAttribute(p[0]);
    });
  });
  var metaDesc = $('meta[name="description"]');

  function applyLang(lang, first) {
    var prev = current;
    current = lang === "es" ? "es" : "en";
    var dict = current === "es" ? ES : EN;
    textNodes.forEach(function (n) {
      var k = n.getAttribute("data-i18n");
      var v = dict[k] != null ? dict[k] : EN[k];
      if (v != null && n.innerHTML !== v) n.innerHTML = v;
    });
    attrNodes.forEach(function (n) {
      n.getAttribute("data-i18n-attr").split(";").forEach(function (pair) {
        var p = pair.split(":");
        var v = dict[p[1]] != null ? dict[p[1]] : EN[p[1]];
        if (v != null) n.setAttribute(p[0], v);
      });
    });
    $$("img[data-src-" + current + "]").forEach(function (img) {
      var src = img.getAttribute("data-src-" + current);
      if (img.getAttribute("src") !== src) img.setAttribute("src", src);
    });
    document.documentElement.lang = current;
    document.title = T().title;
    if (metaDesc) metaDesc.setAttribute("content", T().desc);
    $$(".copy").forEach(function (b) { if (!b.classList.contains("done")) b.querySelector(".copy-label").textContent = T().copy; });
    $$(".lang button").forEach(function (b) { b.setAttribute("aria-pressed", b.getAttribute("data-lang") === current ? "true" : "false"); });
    tickClock();
    if (!first && prev === current) return;
    if (Demo) Demo.relang();
    if (Explorer) Explorer.relang();
  }

  function savedLang() {
    try { var v = localStorage.getItem("kumquat-lang"); if (v === "en" || v === "es") return v; } catch (e) {}
    return null;
  }
  function saveLang(v) { try { localStorage.setItem("kumquat-lang", v); } catch (e) {} }

  $$(".lang button").forEach(function (b) {
    b.addEventListener("click", function () {
      var l = b.getAttribute("data-lang");
      saveLang(l);
      applyLang(l);
    });
  });

  var initial = savedLang();
  if (!initial) {
    var nav = (navigator.language || (navigator.languages && navigator.languages[0]) || "en").toLowerCase();
    initial = nav.indexOf("es") === 0 ? "es" : "en";
  }
  applyLang(initial, true);
})();
