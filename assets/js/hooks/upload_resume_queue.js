const DB_NAME = "vmemo_upload_queue"
const DB_VERSION = 1
const STORE_NAME = "photo_files"
const META_STORE_NAME = "meta"
const META_SESSION_KEY = "current_session_key"

function openDb() {
  return new Promise((resolve, reject) => {
    const request = window.indexedDB.open(DB_NAME, DB_VERSION)

    request.onupgradeneeded = () => {
      const db = request.result
      if (!db.objectStoreNames.contains(STORE_NAME)) {
        db.createObjectStore(STORE_NAME, { keyPath: "id" })
      }
      if (!db.objectStoreNames.contains(META_STORE_NAME)) {
        db.createObjectStore(META_STORE_NAME, { keyPath: "id" })
      }
    }

    request.onsuccess = () => resolve(request.result)
    request.onerror = () => reject(request.error || new Error("open indexeddb failed"))
  })
}

function fileFingerprint(file) {
  return `${file.name}:${file.size}:${file.type}:${file.lastModified}`
}

function buildSessionKey() {
  return `upload_session_${Date.now()}_${Math.random().toString(36).slice(2, 8)}`
}

function toRecords(files) {
  return files.map((file, index) => ({
    id: `${fileFingerprint(file)}:${index}`,
    file,
    order: index,
    name: file.name,
    size: file.size,
    type: file.type,
    lastModified: file.lastModified,
    status: "queued",
    createdAt: new Date().toISOString(),
  }))
}

async function replaceQueuedFiles(files) {
  const db = await openDb()
  const records = toRecords(files)
  const sessionKey = buildSessionKey()

  await new Promise((resolve, reject) => {
    const tx = db.transaction(STORE_NAME, "readwrite")
    const store = tx.objectStore(STORE_NAME)

    store.clear()
    records.forEach((record) => store.put(record))

    tx.oncomplete = () => resolve()
    tx.onerror = () => reject(tx.error || new Error("store files failed"))
  })

  await new Promise((resolve, reject) => {
    const tx = db.transaction(META_STORE_NAME, "readwrite")
    tx.objectStore(META_STORE_NAME).put({ id: META_SESSION_KEY, value: sessionKey })
    tx.oncomplete = () => resolve()
    tx.onerror = () => reject(tx.error || new Error("store meta failed"))
  })

  db.close()
  return { count: records.length, sessionKey, records }
}

async function readQueuedFiles() {
  const db = await openDb()
  const records = await new Promise((resolve, reject) => {
    const tx = db.transaction(STORE_NAME, "readonly")
    const store = tx.objectStore(STORE_NAME)
    const request = store.getAll()

    request.onsuccess = () => {
      const records = (request.result || [])
        .filter((item) => item && item.status === "queued" && item.file)
        .sort((a, b) => a.order - b.order)

      resolve(records)
    }
    request.onerror = () => reject(request.error || new Error("read files failed"))
  })

  const sessionKey = await new Promise((resolve, reject) => {
    const tx = db.transaction(META_STORE_NAME, "readonly")
    const request = tx.objectStore(META_STORE_NAME).get(META_SESSION_KEY)
    request.onsuccess = () => resolve(request.result?.value || null)
    request.onerror = () => reject(request.error || new Error("read meta failed"))
  })

  db.close()
  return {
    sessionKey,
    records,
    files: records.map((record) => record.file),
  }
}

async function clearQueuedFiles() {
  const db = await openDb()
  await new Promise((resolve, reject) => {
    const tx = db.transaction([STORE_NAME, META_STORE_NAME], "readwrite")
    tx.objectStore(STORE_NAME).clear()
    tx.objectStore(META_STORE_NAME).clear()
    tx.oncomplete = () => resolve()
    tx.onerror = () => reject(tx.error || new Error("clear files failed"))
  })
  db.close()
}

function assignFilesToInput(input, files) {
  if (!files.length) return
  const transfer = new DataTransfer()
  files.forEach((file) => transfer.items.add(file))
  input.files = transfer.files
  input.dispatchEvent(new Event("change", { bubbles: true }))
}

function serializeRecords(records) {
  return records.map((record) => ({
    id: record.id,
    order: record.order,
    name: record.name,
    size: record.size,
    type: record.type,
    fingerprint: fileFingerprint(record.file),
  }))
}

export const UploadResumeQueue = {
  mounted() {
    this.onChange = async () => {
      const files = Array.from(this.el.files || [])

      if (!files.length) return

      try {
        const result = await replaceQueuedFiles(files)
        this.pushEvent("queue-persisted", {
          count: result.count,
          client_session_key: result.sessionKey,
          files: serializeRecords(result.records),
        })
      } catch (error) {
        this.pushEvent("queue-persist-failed", { reason: error?.message || "indexeddb_error" })
      }
    }

    this.onClear = () => {
      clearQueuedFiles().catch(() => {
        // no-op
      })
    }

    this.el.addEventListener("change", this.onChange)
    window.addEventListener("phx:upload_queue_clear", this.onClear)

    this.restoreQueue()
  },

  destroyed() {
    this.el.removeEventListener("change", this.onChange)
    window.removeEventListener("phx:upload_queue_clear", this.onClear)
  },

  async restoreQueue() {
    try {
      const payload = await readQueuedFiles()
      if (payload.files.length === 0) return
      assignFilesToInput(this.el, payload.files)
      this.pushEvent("queue-restored", {
        count: payload.files.length,
        client_session_key: payload.sessionKey,
        files: serializeRecords(payload.records),
      })
    } catch (error) {
      this.pushEvent("queue-restore-failed", { reason: error?.message || "indexeddb_error" })
    }
  },
}
