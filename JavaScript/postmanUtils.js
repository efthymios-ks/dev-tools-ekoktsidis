postmanUtils = {
  _logger: {
    log: (message, level = "info") => {
      const prefixedMessage = `[Utils] ${message}`;

      switch (level) {
        case "error":
          console.error(prefixedMessage);
          break;
        case "warn":
          console.warn(prefixedMessage);
          break;
        default:
          console.log(prefixedMessage);
      }
    },

    info: (message) => {
      postmanUtils._logger.log(message, "info");
    },

    warning: (message) => {
      postmanUtils._logger.log(message, "warn");
    },

    error: (message) => {
      postmanUtils._logger.log(message, "error");
    },
  },

  collection: {
    /**
     * Sets collection variables based on active environment name prefix
     * Looks for variables with pattern: {environmentName}_{variableName}
     * @example postmanUtils.collection.setEnvironmentVariables();
     */
    setEnvironmentVariables: () => {
      const environmentName = pm.environment.name;
      if (!environmentName) {
        return;
      }

      const environmentPrefix = `${environmentName.toLowerCase()}_`;
      const collectionVariables = pm.collectionVariables.toObject();
      for (const key in collectionVariables) {
        if (!key.toLowerCase().startsWith(environmentPrefix)) {
          continue;
        }

        const newKey = `${key.substring(environmentPrefix.length)}`;
        pm.collectionVariables.set(newKey, collectionVariables[key]);
      }
    },

    /**
     * Fetches external JavaScript libraries from CDN URLs
     * Looks for js_src_{libraryName} variables and downloads to js_{libraryName}
     * @returns {Promise<void>}
     * @example postmanUtils.collection.fetchJsLibraries();
     */
    fetchJsLibraries: () => {
      return new Promise((resolve, reject) => {
        const collectionVars = pm.collectionVariables.toObject();
        const jsSrcPattern = /^js_src_(.+)$/;

        // Find all js_src_{libraryName} variables that need to be fetched
        const librariesToFetch = [];
        for (const key in collectionVars) {
          // No match - Skip
          const match = key.match(jsSrcPattern);
          if (!match) {
            continue;
          }

          const libraryName = match[1];
          const srcUrl = collectionVars[key];

          // Not a valid URL - Skip
          if (!srcUrl || typeof srcUrl !== "string" || !srcUrl.trim()) {
            postmanUtils._logger.warning(`Skipping ${key}: Invalid or empty URL`);
            continue;
          }

          // Already fetched - Skip
          const jsVarKey = `js_${libraryName}`;
          const jsVarValue = collectionVars[jsVarKey];
          if (jsVarValue && jsVarValue.trim() !== "") {
            postmanUtils._logger.info(`${libraryName}: Already fetched, skipping download`);
            continue;
          }

          // Add to fetch list
          librariesToFetch.push({
            srcKey: key,
            jsKey: jsVarKey,
            libraryName,
            url: srcUrl.trim(),
          });
        }

        if (librariesToFetch.length === 0) {
          postmanUtils._logger.info(
            "All external libraries already fetched or no libraries to fetch"
          );
          resolve();
          return;
        }

        postmanUtils._logger.info(`Found ${librariesToFetch.length} library(ies) to download...`);

        // Fetch libraries sequentially
        let fetchedCount = 0;
        const errors = [];

        const fetchNext = () => {
          if (fetchedCount >= librariesToFetch.length) {
            if (errors.length > 0) {
              postmanUtils._logger.error(`${errors.length} library(ies) failed to fetch`);
              reject(new Error(`${errors.length} library(ies) failed to fetch`));
            } else {
              postmanUtils._logger.info("All external libraries fetched successfully!");
              resolve();
            }
            return;
          }

          const lib = librariesToFetch[fetchedCount];
          postmanUtils._logger.info(`Downloading ${lib.libraryName} from ${lib.url}...`);

          pm.sendRequest(lib.url, (error, response) => {
            if (error) {
              postmanUtils._logger.error(
                `Failed to download ${lib.libraryName}: ${error.message || error}`
              );
              errors.push({ library: lib.libraryName, error });
              fetchedCount++;
              fetchNext();
              return;
            }

            try {
              const libraryCode = response.text();
              pm.collectionVariables.set(lib.jsKey, libraryCode);
              postmanUtils._logger.info(`${lib.libraryName} downloaded and saved successfully`);
            } catch (error) {
              postmanUtils._logger.error(
                `Failed to save ${lib.libraryName}: ${error.message || error}`
              );
              errors.push({ library: lib.libraryName, error });
            }

            fetchedCount++;
            fetchNext();
          });
        };

        fetchNext();
      });
    },

    /**
     * Loads and executes a JavaScript library in the provided context
     * @param {object} context - The context (this) to bind the library to
     * @param {string} name - Library name (without js_ prefix)
     * @example postmanUtils.collection.loadJsLibrary(this, "dayjs");
     */
    loadJsLibrary: (context, name) => {
      if (!name || typeof name !== "string") {
        throw new Error("Invalid library name provided to loadJsLibrary");
      }

      const jsVarKey = `js_${name}`;
      const libraryCode = pm.collectionVariables.get(jsVarKey);

      if (!libraryCode || libraryCode.trim() === "") {
        throw new Error(
          `Library '${name}' not found. Ensure: 1) js_src_${name} is set with a valid CDN URL, 2) js_${name} has content.`
        );
      }

      try {
        // Execute library code with the provided context (this)
        new Function(libraryCode).call(context);
        postmanUtils._logger.info(`${name} loaded successfully`);
      } catch (error) {
        postmanUtils._logger.error(`Failed to load ${name}: ${error.message || error}`);
        throw error;
      }
    },
  },
};

postmanUtils.collection.setEnvironmentVariables();
postmanUtils.collection.fetchJsLibraries();
