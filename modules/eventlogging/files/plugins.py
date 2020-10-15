import dateutil.parser
import json
import time
import unittest
import logging

"""
Only EventLogging schemas that match entries in this list
will be written to the eventlogging-valid-mixed topic
by the eventlogging client side processors.
"""
eventlogging_valid_mixed_schema_whitelist = (
    'AdvancedSearchRequest',
    'CentralAuth',
    'ChangesListClickTracking',
    'ChangesListFilterGrouping',
    'ChangesListFilters',
    'ChangesListHighlights',
    'CitationUsage',
    'ContentTranslation',
    'ContentTranslationAbuseFilter',
    'ContentTranslationCTA',
    'ContentTranslationError',
    'ContentTranslationSuggestion',
    'EchoInteraction',
    'EchoMail',
    'Edit',
    'EditConflict',
    'EditorActivation',
    'EUCCStats',
    'EUCCVisit',
    'ExternalLinksChange',
    'FlowReplies',
    'GeoFeatures',
    'GettingStartedRedirectImpression',
    'GuidedTourButtonClick',
    'GuidedTourExited',
    'GuidedTourExternalLinkActivation',
    'GuidedTourGuiderHidden',
    'GuidedTourGuiderImpression',
    'GuidedTourInternalLinkActivation',
    'InputDeviceDynamics',
    'Kartographer',
    'LandingPageImpression',
    'MediaViewer',
    'MediaWikiPingback',
    'MobileAppCategorizationAttempts',
    'MobileAppLoginAttempts',
    'MobileAppUploadAttempts',
    'MobileWebMainMenuClickTracking',
    'MobileWebSearch',
    'MobileWikiAppAppearanceSettings',
    'MobileWikiAppArticleSuggestions',
    'MobileWikiAppCreateAccount',
    'MobileWikiAppDailyStats',
    'MobileWikiAppEdit',
    'MobileWikiAppFeed',
    'MobileWikiAppFeedConfigure',
    'MobileWikiAppFindInPage',
    'MobileWikiAppInstallReferrer',
    'MobileWikiAppIntents',
    'MobileWikiAppiOSFeed',
    'MobileWikiAppiOSLoginAction',
    'MobileWikiAppiOSReadingLists',
    'MobileWikiAppiOSSessions',
    'MobileWikiAppiOSSettingAction',
    'MobileWikiAppiOSUserHistory',
    'MobileWikiAppLangSelect',
    'MobileWikiAppLanguageSearching',
    'MobileWikiAppLanguageSettings',
    'MobileWikiAppLinkPreview',
    'MobileWikiAppLogin',
    'MobileWikiAppMediaGallery',
    'MobileWikiAppNavMenu',
    'MobileWikiAppOfflineLibrary',
    'MobileWikiAppOnboarding',
    'MobileWikiAppOnThisDay',
    'MobileWikiAppPageScroll',
    'MobileWikiAppProtectedEditAttempt',
    'MobileWikiAppRandomizer',
    'MobileWikiAppReadingLists',
    'MobileWikiAppSavedPages',
    'MobileWikiAppSearch',
    'MobileWikiAppSessions',
    'MobileWikiAppShareAFact',
    'MobileWikiAppStuffHappens',
    'MobileWikiAppTabs',
    'MobileWikiAppToCInteraction',
    'MobileWikiAppWidgets',
    'MobileWikiAppWiktionaryPopup',
    'MultimediaViewerAttribution',
    'MultimediaViewerDimensions',
    'MultimediaViewerDuration',
    'MultimediaViewerNetworkPerformance',
    'MultimediaViewerVersusPageFilePerformance',
    'NavigationTiming',
    'PrefUpdate',
    'QuickSurveyInitiation',
    'QuickSurveysResponses',
    'RelatedArticles',
    'SaveTiming',
    'ServerSideAccountCreation',
    'TranslationRecommendationAPIRequests',
    'TranslationRecommendationUIRequests',
    'TranslationRecommendationUserAction',
    'TwoColConflictConflict',
    'UniversalLanguageSelector',
    'UploadWizardErrorFlowEvent',
    'UploadWizardExceptionFlowEvent',
    'UploadWizardFlowEvent',
    'UploadWizardStep',
    'UploadWizardTutorialActions',
    'UploadWizardUploadFlowEvent',
    'WikidataCompletionSearchClicks',
    'WikimediaBlogVisit',
    'WikipediaPortal',
    'WikipediaZeroUsage',
    'WMDEBannerEvents',
    'WMDEBannerSizeIssue',
)


def eventlogging_valid_mixed_filter(event):
    """
    Returns None if this event's schema_name is not in
    eventlogging_valid_mixed_schema_whitelist, else the event.
    """
    if event.get('schema', '') not in eventlogging_valid_mixed_schema_whitelist:
        return None

    return event


"""
If a schema is in this list, it will be mapped to None, causing
eventlogging-processor to skip it.  This will be used
for the migration to Event Platform, away from the python eventlogging
backend.  Once a schema has been fully migrated to an Event Platform stream,
it can be added to this list.
See: https://phabricator.wikimedia.org/T259163
"""
eventlogging_schemas_disabled = (
    'SearchSatisfaction',
    'TemplateWizard',
    'Test',
)


def eventlogging_schemas_disabled_filter(event):
    """
    Returns None if this event's schema_name is in
    eventlogging_schemas_disabled list, else the event.
    """
    schema_name = event.get('schema', '')
    if schema_name in eventlogging_schemas_disabled:
        logging.warn('Encountered event with disabled schema %s, skipping.', schema_name)
        return None

    return event


def mysql_mapper(event):
    """
    The WMF EventLogging Analytics MySQL log database has a lot of curious
    legacy compatibility problems.  This function converts an event
    to a format that the MySQL database expects.  If an event comes from
    a non-MediaWiki bot, it will be mapped to 'None' and thus excluded from the stream.
    """
    if 'userAgent' in event and isinstance(event['userAgent'], dict):
        # Get rid of unwanted bots. T67508
        is_bot = event['userAgent'].get('is_bot', False)
        is_mediawiki = event['userAgent'].get('is_mediawiki', False)
        # Don't insert events generated by bots unless they are mediawiki bots.
        if is_bot and not is_mediawiki:
            # Returning None will cause map://
            # reader to exclude this event.
            return None

        # MySQL expects that userAgent is a string, so we
        # convert it to JSON string now.  T153207
        event['userAgent'] = json.dumps(event['userAgent'])

    # jrm.py expects an integer `timestamp` field to convert into
    #  MediaWiki timestamp. Inject it into the event.
    if 'dt' in event:
        # Use the time from `dt`
        event['timestamp'] = int(dateutil.parser.parse(event['dt']).strftime("%s"))
        # Historicaly, EventCapsule did not have `dt` so we remove it from
        # insertion into MySQL.
        del event['dt']
    else:
        # Else just use current time.
        event['timestamp'] = int(time.time())

    return event


# ##### Tests ######
# To run:
#   python -m unittest -v plugins.py
# Or:
#   python plugins.py
#
class TestEventLoggingPlugins(unittest.TestCase):
    def test_eventlogging_valid_mixed_filter(self):
        e1 = {
            'dt': '2017-11-01T11:00:00',
            'schema': 'Edit',
            'revision': 123,
        }
        self.assertEqual(eventlogging_valid_mixed_filter(e1), e1)

        e2 = {
            'dt': '2017-11-01T11:00:00',
            'schema': 'EditNotWhitelisted',
            'revision': 456,
        }
        self.assertEqual(eventlogging_valid_mixed_filter(e2), None)

    def test_mysql_mapper(self):
        e1 = {
            'dt': '2017-11-01T11:00:00',
            'userAgent': {'browser_family': 'Chrome'}
        }
        should_be1 = {'timestamp': 1509548400, 'userAgent': '{"browser_family": "Chrome"}'}
        self.assertEqual(mysql_mapper(e1), should_be1)

        e2 = {
            'dt': '2017-11-01T11:00:00',
            'userAgent': {'is_bot': True}
        }
        self.assertEqual(mysql_mapper(e2), None)

        e3 = {
            'dt': '2017-11-01T11:00:00',
            'userAgent': {'is_bot': True, 'is_mediawiki': True}
        }
        should_be3 = {'timestamp': 1509548400, 'userAgent': json.dumps(e3['userAgent'])}
        self.assertEqual(mysql_mapper(e3), should_be3)


if __name__ == '__main__':
    unittest.main(verbosity=2)
