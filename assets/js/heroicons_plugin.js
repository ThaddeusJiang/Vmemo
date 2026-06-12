const fs = require("fs")
const path = require("path")
const plugin = require("tailwindcss/plugin")

const heroiconsPackagePath = path.dirname(require.resolve("heroicons/package.json"))
const iconsDir = fs.existsSync(path.join(heroiconsPackagePath, "optimized"))
  ? path.join(heroiconsPackagePath, "optimized")
  : heroiconsPackagePath

module.exports = plugin(function ({ matchComponents, theme }) {
  const values = {}
  const icons = [
    ["", "24/outline"],
    ["-solid", "24/solid"],
    ["-mini", "20/solid"],
    ["-micro", "16/solid"],
  ]

  icons.forEach(([suffix, dir]) => {
    fs.readdirSync(path.join(iconsDir, dir)).forEach((file) => {
      const name = path.basename(file, ".svg") + suffix
      values[name] = { name, fullPath: path.join(iconsDir, dir, file) }
    })
  })

  matchComponents(
    {
      hero: ({ name, fullPath }) => {
        const content = encodeURIComponent(
          fs.readFileSync(fullPath).toString().replace(/\r?\n|\r/g, "")
        )
        let size = theme("spacing.6")

        if (name.endsWith("-mini")) {
          size = theme("spacing.5")
        } else if (name.endsWith("-micro")) {
          size = theme("spacing.4")
        }

        return {
          [`--hero-${name}`]: `url('data:image/svg+xml;utf8,${content}')`,
          "-webkit-mask": `var(--hero-${name})`,
          mask: `var(--hero-${name})`,
          "mask-repeat": "no-repeat",
          "background-color": "currentColor",
          "vertical-align": "middle",
          display: "inline-block",
          width: size,
          height: size,
        }
      },
    },
    { values }
  )
})
