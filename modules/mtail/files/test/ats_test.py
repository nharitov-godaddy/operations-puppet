# SPDX-License-Identifier: Apache-2.0
import mtail_store
import unittest
import os

test_dir = os.path.join(os.path.dirname(__file__))


class ATSBackendTest(unittest.TestCase):
    def setUp(self):
        self.store = mtail_store.MtailMetricStore(
                os.path.join(test_dir, '../programs/atsbackend.mtail'),
                os.path.join(test_dir, 'logs/atsbackend.test'))

    def testRespStatus(self):
        s = self.store.get_samples('trafficserver_backend_requests_seconds_count')
        self.assertIn(('status=200,method=GET,backend=swift.discovery.wmnet', 3), s)

        s = self.store.get_samples('trafficserver_backend_connections_total')
        self.assertIn(('backend=swift.discovery.wmnet', 1), s)

        bucket_samples = self.store.get_samples('trafficserver_backend_requests_seconds_bucket')
        self.assertIn(('le=0.1,method=GET,backend=appservers-rw.discovery.wmnet', 1),
                      bucket_samples)
        self.assertIn(('le=0.07,method=GET,backend=swift.discovery.wmnet', 1),
                      bucket_samples)
        self.assertIn(('le=0.25,method=GET,backend=swift.discovery.wmnet', 4),
                      bucket_samples)

        sum_samples = self.store.get_samples('trafficserver_backend_requests_seconds_sum')
        self.assertIn(('status=304,method=GET,backend=swift.discovery.wmnet', 0.055),
                      sum_samples)

    def testBackendClientMetrics(self):
        s = self.store.get_samples('trafficserver_backend_client_cache_read_time')
        cache_read_dict = dict(s)
        self.assertEqual(cache_read_dict['backend=swift.discovery.wmnet']['sum'], 15)
        self.assertEqual(cache_read_dict['backend=swift.discovery.wmnet']['buckets']['1'], 1)

        s = self.store.get_samples('trafficserver_backend_client_cache_write_time')
        cache_write_dict = dict(s)
        self.assertEqual(cache_write_dict['backend=appservers-rw.discovery.wmnet']['sum'], 3)
        self.assertEqual(cache_write_dict['backend=appservers-rw.discovery.wmnet']['buckets']['5'],
                         1)

        bucket_samples = self.store.get_samples('trafficserver_backend_client_ttfb')
        bucket_dict = dict(bucket_samples)
        self.assertEqual(bucket_dict['backend=swift.discovery.wmnet']['buckets']['0.15'], 4)

        samples = self.store.get_samples('trafficserver_backend_cache_result_code_client_ttfb')
        bucket_dict = dict(samples)
        refresh_hit_labels = 'backend=swift.discovery.wmnet,cache_result_code=TCP_REFRESH_HIT'
        miss_labels = 'backend=swift.discovery.wmnet,cache_result_code=TCP_MISS'
        self.assertEqual(bucket_dict[refresh_hit_labels]['buckets']['0.15'], 1)
        self.assertEqual(bucket_dict[miss_labels]['buckets']['0.15'], 3)

    def testPluginTimeMetrics(self):
        s = self.store.get_samples('trafficserver_backend_total_plugin_time')
        s_dict = dict(s)

        self.assertIn('backend=swift.discovery.wmnet', s_dict)
        self.assertIn('backend=appservers-rw.discovery.wmnet', s_dict)

        self.assertEqual(s_dict['backend=swift.discovery.wmnet']['buckets']['0.01'], 1)
        self.assertEqual(s_dict['backend=swift.discovery.wmnet']['buckets']['0.001'], 1)

        s = self.store.get_samples('trafficserver_backend_active_plugin_time')
        s_dict = dict(s)

        self.assertIn('backend=swift.discovery.wmnet', s_dict)
        self.assertIn('backend=appservers-rw.discovery.wmnet', s_dict)

        self.assertEqual(s_dict['backend=swift.discovery.wmnet']['buckets']['0.001'], 1)
        self.assertEqual(s_dict['backend=swift.discovery.wmnet']['buckets']['0.01'], 1)

    def testSLI(self):
        s = self.store.get_samples('trafficserver_backend_sli_total')
        self.assertIn(('', 8), s)
        s = self.store.get_samples('trafficserver_backend_sli_good')
        self.assertIn(('', 7), s)
        s = self.store.get_samples('trafficserver_backend_sli_bad')
        self.assertIn(('', 1), s)


class ATSBackendTimingTest(unittest.TestCase):
    def setUp(self):
        self.store = mtail_store.MtailMetricStore(
                os.path.join(test_dir, '../programs/atsbackendtiming.mtail'),
                os.path.join(test_dir, 'logs/atsbackendtiming.test'))

    def testBackendTiming(self):
        s = self.store.get_samples('ats_backend_timing_count')
        self.assertIn(('', 3), s)
        s = self.store.get_samples('ats_backend_timing_sum')
        self.assertIn(('', 0.7525828999999999), s)
        s = self.store.get_samples('ats_backend_timing_bucket')
        self.assertIn((u'le=0.25', 2), s)
        self.assertIn((u'le=0.5', 2), s)
        self.assertIn((u'le=1', 2), s)
        self.assertIn((u'le=2.5', 2), s)
        self.assertIn((u'le=5', 2), s)
        self.assertIn((u'le=10', 3), s)
        self.assertIn((u'le=15', 3), s)
        self.assertIn((u'le=+Inf', 3), s)
