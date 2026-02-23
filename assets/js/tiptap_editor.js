import { Editor } from "@tiptap/core"
import StarterKit from "@tiptap/starter-kit"
import Link from "@tiptap/extension-link"
import Underline from "@tiptap/extension-underline"

const TOOLBAR_BUTTONS = [
  {
    label: "B",
    title: "Bold",
    extraClass: "font-bold",
    action: editor => editor.chain().focus().toggleBold().run(),
    isActive: editor => editor.isActive("bold"),
  },
  {
    label: "I",
    title: "Italic",
    extraClass: "italic",
    action: editor => editor.chain().focus().toggleItalic().run(),
    isActive: editor => editor.isActive("italic"),
  },
  {
    label: "U",
    title: "Underline",
    extraClass: "underline",
    action: editor => editor.chain().focus().toggleUnderline().run(),
    isActive: editor => editor.isActive("underline"),
  },
  {
    label: "H1",
    title: "Heading 1",
    action: editor => editor.chain().focus().toggleHeading({ level: 1 }).run(),
    isActive: editor => editor.isActive("heading", { level: 1 }),
  },
  {
    label: "H2",
    title: "Heading 2",
    action: editor => editor.chain().focus().toggleHeading({ level: 2 }).run(),
    isActive: editor => editor.isActive("heading", { level: 2 }),
  },
  {
    label: "•",
    title: "Bullet List",
    action: editor => editor.chain().focus().toggleBulletList().run(),
    isActive: editor => editor.isActive("bulletList"),
  },
  {
    label: "1.",
    title: "Ordered List",
    action: editor => editor.chain().focus().toggleOrderedList().run(),
    isActive: editor => editor.isActive("orderedList"),
  },
  {
    label: "Link",
    title: "Link",
    action: editor => {
      if (editor.isActive("link")) {
        editor.chain().focus().unsetLink().run()
      } else {
        const url = prompt("URL:")
        if (url) editor.chain().focus().setLink({ href: url }).run()
      }
    },
    isActive: editor => editor.isActive("link"),
  },
]

const TiptapEditor = {
  mounted() {
    const hiddenInput = document.getElementById("post-body-input")
    const initialContent = this.el.dataset.content || ""

    // Toolbar
    const toolbar = document.createElement("div")
    toolbar.className =
      "flex flex-wrap gap-1 p-2 border border-base-300 rounded-t-lg bg-base-200"

    this._toolbarEntries = TOOLBAR_BUTTONS.map(btn => {
      const el = document.createElement("button")
      el.type = "button"
      el.title = btn.title
      el.textContent = btn.label
      el.className =
        "px-2 py-1 rounded text-sm font-medium text-base-content hover:bg-base-300 transition-colors " +
        (btn.extraClass || "")
      el.addEventListener("mousedown", e => {
        e.preventDefault()
        btn.action(this.editor)
      })
      toolbar.appendChild(el)
      return { el, isActive: btn.isActive }
    })

    // Editor area
    const editorDiv = document.createElement("div")
    editorDiv.className =
      "border border-t-0 border-base-300 rounded-b-lg min-h-64 p-3 prose prose-sm max-w-none bg-base-100"

    this.el.appendChild(toolbar)
    this.el.appendChild(editorDiv)

    this.editor = new Editor({
      element: editorDiv,
      extensions: [
        StarterKit,
        Underline,
        Link.configure({ openOnClick: false }),
      ],
      content: initialContent,
      onUpdate: ({ editor }) => {
        if (hiddenInput) hiddenInput.value = editor.getHTML()
        this._syncToolbar()
      },
      onSelectionUpdate: () => this._syncToolbar(),
    })

    if (hiddenInput) hiddenInput.textContent = this.editor.getHTML()
  },

  _syncToolbar() {
    this._toolbarEntries.forEach(({ el, isActive }) => {
      if (isActive(this.editor)) {
        el.classList.add("bg-base-300", "text-primary")
      } else {
        el.classList.remove("bg-base-300", "text-primary")
      }
    })
  },

  destroyed() {
    if (this.editor) this.editor.destroy()
  },
}

export default TiptapEditor
