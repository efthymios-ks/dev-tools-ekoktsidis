const PostmanUtils = {
  Collection: {
    setEnvironmentVariables: () => {
      const environmentName = pm.environment.name.toLowerCase();
      const environmentPrefix = `${environmentName}_`;
      const collectionVariables = pm.collectionVariables.toObject();
      for (const key in collectionVariables) {
        if (!key.toLowerCase().startsWith(environmentPrefix)) {
          continue;
        }

        const newKey = `${key.substring(environmentPrefix.length)}`;
        pm.collectionVariables.set(newKey, collectionVariables[key]);
      }
    },
  },
};

PostmanUtils.Collection.setEnvironmentVariables();
