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
