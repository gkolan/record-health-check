/**
 * @author Gautam Kolan (https://github.com/gkolan)
 * SPDX-License-Identifier: Apache-2.0
 */

/**
 * Which merge tokens each configuration field accepts, declared as data.
 *
 * These rules used to be a chain of comparisons inside the validator, which
 * meant every new namespace or field added another branch and every rule was
 * stated in the place it happened to be needed. They are a small table instead,
 * so adding a surface is a row and adding a namespace is an entry.
 *
 * The broad surfaces existing callers pass — SURFACE_SOQL, SURFACE_DISPLAY,
 * and SURFACE_URL — are named on RecordHealthCheckTemplateService and appear
 * here as rows. The named surfaces below are narrower and describe one
 * configuration field each, which is what lets a query row token be allowed in
 * the failure message and refused in the not-applicable message.
 */
public class RecordHealthCheckTokenSurfaces {
  public static final String FAILURE_MESSAGE = 'FAILURE_MESSAGE';
  public static final String UNABLE_MESSAGE = 'UNABLE_MESSAGE';
  public static final String NOT_APPLICABLE_MESSAGE = 'NOT_APPLICABLE_MESSAGE';
  public static final String FIX_MESSAGE = 'FIX_MESSAGE';
  public static final String ACTION_LABEL = 'ACTION_LABEL';
  public static final String ACTION_URL = 'ACTION_URL';
  public static final String DISPLAY_FOUND = 'DISPLAY_FOUND';
  public static final String DISPLAY_EXPECTED = 'DISPLAY_EXPECTED';

  private static final Set<String> RECORD_ONLY = new Set<String>{ 'record' };
  private static final Set<String> POST_RUN = new Set<String>{
    'record',
    'rhcCheck',
    'rhcSet',
    'rhcResult',
    'rhcRun',
    'rhcQuery'
  };
  private static final Set<String> POST_RUN_NO_RESULT = new Set<String>{
    'record',
    'rhcCheck',
    'rhcSet',
    'rhcRun',
    'rhcQuery'
  };
  /**
   * Everything the broad DISPLAY surface has always accepted, minus query rows.
   *
   * The not-applicable message is written when the Check's queries never ran,
   * so a query row token there would always be blank. Result tokens are a
   * different matter: the runtime resolves this message through the same
   * finalized-result path as every other message, and metadata authored before
   * this change may already use them. Excluding them would reject configuration
   * that installs and works today.
   */
  private static final Set<String> POST_RUN_NO_QUERY = new Set<String>{
    'record',
    'rhcCheck',
    'rhcSet',
    'rhcResult',
    'rhcRun'
  };

  /**
   * The namespaces each surface accepts.
   *
   * A SOQL template may only read the record, because a query cannot reference
   * output that does not exist until it has run. The not-applicable message is
   * written when the Check's queries never executed, so a query token there
   * would always be blank and would mislead its author. Action URLs exclude
   * result tokens, which hold finished prose rather than a value safe to place
   * in a path.
   */
  private static final Map<String, Set<String>> ALLOWED_NAMESPACES = new Map<String, Set<String>>{
    RecordHealthCheckTemplateService.SURFACE_SOQL => RECORD_ONLY,
    RecordHealthCheckTemplateService.SURFACE_DISPLAY => POST_RUN,
    RecordHealthCheckTemplateService.SURFACE_URL => POST_RUN_NO_RESULT,
    FAILURE_MESSAGE => POST_RUN,
    UNABLE_MESSAGE => POST_RUN,
    NOT_APPLICABLE_MESSAGE => POST_RUN_NO_QUERY,
    FIX_MESSAGE => POST_RUN,
    ACTION_LABEL => POST_RUN,
    ACTION_URL => POST_RUN_NO_RESULT,
    DISPLAY_FOUND => POST_RUN,
    DISPLAY_EXPECTED => POST_RUN
  };

  /**
   * Surfaces where `format` can mean something.
   *
   * A URL carries canonical values, not values punctuated for a reader, and a
   * SOQL template is bound rather than rendered.
   */
  private static final Set<String> FORMATTING = new Set<String>{
    RecordHealthCheckTemplateService.SURFACE_DISPLAY,
    FAILURE_MESSAGE,
    UNABLE_MESSAGE,
    NOT_APPLICABLE_MESSAGE,
    FIX_MESSAGE,
    ACTION_LABEL,
    DISPLAY_FOUND,
    DISPLAY_EXPECTED
  };

  /** True when this surface accepts tokens from this namespace. */
  public static Boolean allows(String surface, String namespaceName) {
    Set<String> allowed = ALLOWED_NAMESPACES.get(surface);
    return allowed != null && allowed.contains(namespaceName);
  }

  /** True when a `format` attribute is meaningful on this surface. */
  public static Boolean allowsFormat(String surface) {
    return FORMATTING.contains(surface);
  }
}
