/** Optional subscriber contract for declaring plugin parameters and capacity. */
global interface RecordHealthCheckPluginDefinitionSource {
  /** Returns this plugin instance's static definition. */
  RecordHealthCheckPluginDefinition getDefinition();
}
