return {
  {
    "mfussenegger/nvim-jdtls",
    opts = function(_, opts)
      -- JDK / Gradle paths - UPDATE THESE to match your system
      local jdk17_path = "C:\\Users\\539099\\Projects\\Java\\jdk17.0.10_7" -- Your JDK 17 installation
      local jdk21_path = "C:\\Users\\539099\\Projects\\Java\\jdk21.0.9_10" -- Your JDK 21 installation
      local jdk25_path = "C:\\Users\\539099\\Projects\\Java\\jdk25.0.4_8" -- Your JDK 25 installation
      local gradle_home_path = "C:\\Users\\539099\\Projects\\gradle\\gradle-9.3.1" -- Gradle 9.1+ can run on Java 25

      -- jdtls requires Java 21+ to run, but projects may need Java 17 or 25
      -- Set JAVA_HOME to JDK 21 for jdtls
      vim.env.JAVA_HOME = jdk21_path
      -- Also expose JDK 17 path for Gradle to find
      vim.env.JDK17_HOME = jdk17_path

      -- The builds declare the JDK they need as `reqJavaVer` in gradle.properties and fail at
      -- configuration time when Gradle runs on any other JDK, so pick the Gradle JDK per project.
      -- Java 25 projects have no Gradle wrapper, so they use the local Gradle install instead.
      local gradle_jdks = {
        ["17"] = { home = jdk17_path },
        ["21"] = { home = jdk21_path },
        ["25"] = { home = jdk25_path, gradle_home = gradle_home_path },
      }
      local default_gradle_jdk = gradle_jdks["17"] -- projects that don't declare reqJavaVer

      local function required_java_version(root_dir)
        local file = root_dir and io.open(root_dir .. "/gradle.properties", "r")
        if not file then
          return nil
        end
        local version
        for line in file:lines() do
          version = line:match("^%s*reqJavaVer%s*[=:]%s*(%S+)")
          if version then
            break
          end
        end
        file:close()
        return version
      end

      -- Configure project runtimes
      -- Projects use JDK 17 by default; jdtls itself runs on Java 21
      opts.settings = vim.tbl_deep_extend("force", opts.settings or {}, {
        java = {
          configuration = {
            runtimes = {
              {
                name = "JavaSE-17",
                path = jdk17_path,
                default = true, -- Projects compile/run with Java 17 unless they require another JDK
              },
              {
                name = "JavaSE-21",
                path = jdk21_path,
              },
              {
                name = "JavaSE-25",
                path = jdk25_path,
              },
            },
          },
          -- Optional: Set source/target compatibility
          compile = {
            nullAnalysis = {
              mode = "automatic",
            },
          },
          -- Eclipse settings
          eclipse = {
            downloadSources = true,
          },
          maven = {
            downloadSources = true,
          },
          implementationsCodeLens = {
            enabled = true,
          },
          referencesCodeLens = {
            enabled = true,
          },
          references = {
            includeDecompiledSources = true,
          },
          format = {
            enabled = true,
          },
          symbols = {
            includeSourceMethodResolution = true,
          },
          contentProvider = {
            preferred = "fernflower",
          },
          project = {
            resourceFilters = {
              "node_modules",
              ".git",
            },
          },
        },
      })

      -- Runs per attached buffer with the final config, so the Gradle JDK can depend on the project root
      opts.jdtls = function(config)
        local jdk = gradle_jdks[required_java_version(config.root_dir)] or default_gradle_jdk
        local gradle = { java = { home = jdk.home } }
        if jdk.gradle_home then
          gradle.home = jdk.gradle_home
          gradle.wrapper = { enabled = false }
        end
        config.settings = vim.tbl_deep_extend("force", config.settings or {}, {
          java = { import = { gradle = gradle } },
        })
        -- jdtls starts importing Gradle projects before didChangeConfiguration delivers the settings,
        -- which would run the first import on jdtls's own JVM
        config.init_options = vim.tbl_extend("force", config.init_options or {}, { settings = config.settings })
        return config
      end

      return opts
    end,
  },
}
