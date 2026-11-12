import importlib.util
import json
import tempfile
import unittest
from pathlib import Path
from unittest.mock import Mock, patch

PATH = Path(__file__).resolve().parent.parent / 'hkit-hy2hop.py'
spec = importlib.util.spec_from_file_location('hkit_hy2hop_source', PATH)
m = importlib.util.module_from_spec(spec)
spec.loader.exec_module(m)
m.setup_service = Mock(); m.other_firewall_hint = Mock(); m.legacy_nat_rules = lambda: []


def hkit_state(*nodes):
    return {'schema_version': 1, 'protocols': {'reality': [], 'hysteria2': list(nodes)}}


NODE = {'id': 'hysteria2-primary', 'enabled': True, 'name': 'Hkit-Hysteria2',
        'params': {'port': 8443, 'sni': 'x.app'}}


class HkitSourceTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory(); self.addCleanup(self.tmp.cleanup)
        self.state = Path(self.tmp.name) / 'state.json'
        p = patch.object(m, 'HKIT_STATE', self.state); p.start(); self.addCleanup(p.stop)

    def write(self, data):
        self.state.write_text(json.dumps(data))

    def test_reads_enabled_hysteria2_port(self):
        self.write(hkit_state(NODE))
        self.assertEqual(m.hkit_hysteria2(),
                         {'id': 'hysteria2-primary', 'remark': 'Hkit-Hysteria2', 'port': 8443})

    def test_missing_state_means_hkit_not_installed(self):
        with self.assertRaisesRegex(RuntimeError, '未找到 Hkit 状态文件'):
            m.hkit_hysteria2()

    def test_disabled_or_absent_hysteria2_rejected(self):
        self.write(hkit_state(dict(NODE, enabled=False)))
        with self.assertRaisesRegex(RuntimeError, '没有启用 Hysteria2'):
            m.hkit_hysteria2()

    def test_multiple_nodes_rejected(self):
        self.write(hkit_state(NODE, dict(NODE, id='second')))
        with self.assertRaisesRegex(RuntimeError, '多个 Hysteria2'):
            m.hkit_hysteria2()

    def test_invalid_port_rejected(self):
        self.write(hkit_state(dict(NODE, params={'port': 'x'})))
        with self.assertRaisesRegex(RuntimeError, '端口无效'):
            m.hkit_hysteria2()

    def test_default_range_when_non_interactive(self):
        self.write(hkit_state(NODE))
        with patch.object(m.sys.stdin, 'isatty', return_value=False):
            cfg = m.choose()
        self.assertEqual(cfg, {'id': 'hysteria2-primary', 'remark': 'Hkit-Hysteria2',
                               'port': 8443, 'start': 20000, 'end': 30000})

    def test_explicit_range_and_update_keeps_installed_range(self):
        self.write(hkit_state(NODE))
        cfg = m.choose('40000-41000')
        self.assertEqual((cfg['start'], cfg['end']), (40000, 41000))
        old = {'start': 31000, 'end': 32000}
        cfg = m.choose(None, old)
        self.assertEqual((cfg['start'], cfg['end']), (31000, 32000))

    def test_range_must_not_contain_listen_port(self):
        self.write(hkit_state(NODE))
        with self.assertRaisesRegex(RuntimeError, '包含 Hysteria2 监听端口 8443'):
            m.choose('8000-9000')

    def test_bad_range_formats(self):
        for bad in ('20000', '30000-20000', '0-100', '20000-70000', 'a-b'):
            with self.assertRaises(ValueError, msg=bad):
                m.parse_range(bad)

    def test_status_reports_changed_hkit_port(self):
        self.write(hkit_state(dict(NODE, params={'port': 9443})))
        state = {'config': {'id': 'hysteria2-primary', 'remark': 'Hkit-Hysteria2', 'port': 8443,
                            'start': 20000, 'end': 30000}, 'families': ['ip'], 'ufw_owned': []}

        def fake_run(cmd, check=True, input_text=None):
            if cmd[:3] == ['nft', 'list', 'chain']:
                return Mock(returncode=0, stdout='udp dport 20000-30000 counter packets 0 bytes 0 redirect to :8443')
            if cmd[:2] == ['systemctl', 'is-enabled']:
                return Mock(returncode=0, stdout='enabled\n')
            return Mock(returncode=0, stdout='')

        with patch.object(m, 'read_state', return_value=state), patch.object(m, 'listener'), \
             patch.object(m, 'ufw_active', return_value=False), patch.object(m, 'run', side_effect=fake_run), \
             patch('builtins.print') as out:
            rc = m.status()
        self.assertEqual(rc, 1)
        printed = '\n'.join(' '.join(map(str, c.args)) for c in out.call_args_list)
        self.assertIn('端口已变为 9443，请执行 update', printed)

    def test_client_hint_lists_all_client_formats(self):
        hint = m.client_hint({'port': 8443, 'start': 20000, 'end': 30000})
        for text in ('ports: "20000-30000"', 'server_ports: ["20000:30000"]', 'mport=20000-30000',
                     'sudo hkit-hy2hop restore'):
            self.assertIn(text, hint)

    def test_names_do_not_collide_with_hysteria2_hop(self):
        self.assertEqual((m.TABLE, m.SERVICE, str(m.SELF)),
                         ('hkit_hy2hop', 'hkit-hy2hop.service', '/usr/local/sbin/hkit-hy2hop'))
        self.assertIn('After=network-online.target nftables.service ufw.service firewalld.service '
                      'hkit-hysteria2.service', m.unit_content())


if __name__ == '__main__':
    unittest.main()
