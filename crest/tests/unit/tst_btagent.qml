import QtQuick
import QtTest
import "../../utils/btagent.js" as Agent

TestCase {
    name: "btagent"

    readonly property string session: "Waiting to connect to bluetoothd...Unable to open mgmt_socket\n\n\u001b[0;94m[bluetooth]\u001b[0m# \nAgent registered\n\u001b[0;94m[bluetooth]\u001b[0m# default-agent\n\u001b[0;94m[bluetooth]\u001b[0m# \nDefault agent request successful\n\u001b[0;94m[bluetooth]\u001b[0m# \nRequest confirmation\n\u001b[0;94m[bluetooth]\u001b[0m# \n\u001b[1;39m[agent] Confirm passkey 000042 (yes/no): \u001b[0myes\n\u001b[0;94m[bluetooth]\u001b[0m# \nRequest passkey\n\u001b[0;94m[bluetooth]\u001b[0m# \n\u001b[1;39m[agent] Enter passkey (number in 0-999999): \u001b[0m1234\n\u001b[0;94m[bluetooth]\u001b[0m# \nRequest PIN code\n\u001b[0;94m[bluetooth]\u001b[0m# \n\u001b[1;39m[agent] Enter PIN code: \u001b[0m0000\n\u001b[0;94m[bluetooth]\u001b[0m# \nRequest authorization\n\u001b[0;94m[bluetooth]\u001b[0m# \n\u001b[1;39m[agent] Accept pairing (yes/no): \u001b[0mno\n\u001b[0;94m[bluetooth]\u001b[0m# \nAuthorize service\n\u001b[0;94m[bluetooth]\u001b[0m# \n\u001b[1;39m[agent] Authorize service 0000110b-0000-1000-8000-00805f9b34fb (yes/no): \u001b[0myes\n\u001b[0;94m[bluetooth]\u001b[0m# \n\u001b[0;91m[agent]\u001b[0m Passkey: \u001b[1;30m00\u001b[1;37m0005\n\u001b[0m\u001b[0;94m[bluetooth]\u001b[0m# \n\u001b[0;91m[agent]\u001b[0m PIN code: 1234\n\u001b[0;94m[bluetooth]\u001b[0m# \nRequest confirmation\n\u001b[0;94m[bluetooth]\u001b[0m# \n\u001b[1;39m[agent] Confirm passkey 000007 (yes/no): \u001b[0mRequest canceled\n\u001b[1;39m[agent] Confirm passkey 000007 (yes/no): \u001b[0m\n\u001b[0;94m[bluetooth]\u001b[0m# \u001b[Kquit\n\u001b[0;94m[bluetooth]\u001b[0m# quit\n\u001b[0;94m[bluetooth]\u001b[0m# \n"

    function run(chunks) {
        const state = Agent.create();
        let events = [];
        for (const c of chunks)
            events = events.concat(Agent.feed(state, c));
        return events.filter(e => e.type !== "device");
    }

    function check(events) {
        const kinds = events.map(e => e.type === "request" || e.type === "display" ? `${e.type}:${e.kind}` : e.type);
        compare(kinds, ["lost", "registered", "default", "request:confirm", "request:passkey", "request:pin", "request:authorize", "request:service", "display:passkey", "display:pin", "request:confirm", "cancel"]);
        compare(events[3].code, "000042");
        compare(events[7].uuid, "0000110b-0000-1000-8000-00805f9b34fb");
        compare(events[8].code, "000005");
        compare(events[8].entered, 2);
        compare(events[9].code, "1234");
        compare(events[10].code, "000007");
    }

    function test_whole_session() {
        check(run([session]));
    }

    function test_byte_by_byte() {
        check(run(session.split("")));
    }

    function test_prompt_without_newline() {
        const state = Agent.create();
        compare(Agent.feed(state, "\r\x1b[0;94m[bluetooth]\x1b[0m# \rRequest confirmation\n").length, 0);
        const ev = Agent.feed(state, "\x1b[0;94m[bluetooth]\x1b[0m# \r\x1b[1;39m[agent] Confirm passkey 123456 (yes/no): \x1b[0m");
        compare(ev.length, 1);
        compare(ev[0].code, "123456");
        compare(Agent.feed(state, "yes\n").length, 0);
    }

    function test_bluez_588_prompt() {
        const state = Agent.create();
        const start = Agent.feed(state, "Waiting to connect to bluetoothd...\r\x1b[19P\x1b[0;94m[bluetoothctl]> \x1b[0m\r\x1b[K\rAgent registered\n\x1b[0;94m[bluetoothctl]> \x1b[0mdefault-agent\n\x1b[0;94m[bluetoothctl]> \x1b[0m\r\x1b[K\rDefault agent request successful\n");
        compare(start.map(e => e.type), ["lost", "registered", "default"]);
        Agent.feed(state, "\x1b[0;94m[bluetoothctl]> \x1b[0m\r\x1b[K\rRequest confirmation\n");
        const ev = Agent.feed(state, "\x1b[0;94m[bluetoothctl]> \x1b[0m\r\x1b[K\r\x1b[1;39m[agent] Confirm passkey 654321 (yes/no): \x1b[0m");
        compare(ev.length, 1);
        compare(ev[0].code, "654321");
    }

    function test_prompt_needs_marker() {
        const state = Agent.create();
        compare(Agent.feed(state, "[agent] Confirm passkey 123456 (yes/no): \n").length, 0);
    }

    function test_device_lines() {
        const state = Agent.create();
        const ev = Agent.feed(state, "\r[\x1b[0;93mCHG\x1b[0m] Device aa:bb:cc:dd:ee:ff Connected: yes\n[\x1b[0;92mNEW\x1b[0m] Device 11:22:33:44:55:66 Pixel\n");
        compare(ev.map(e => e.address), ["AA:BB:CC:DD:EE:FF", "11:22:33:44:55:66"]);
    }

    function test_lost() {
        const state = Agent.create();
        compare(Agent.feed(state, "Waiting to connect to bluetoothd...\n")[0].type, "lost");
        compare(Agent.feed(state, "Agent released\n")[0].type, "lost");
    }

    function test_answers() {
        compare(Agent.answer("confirm", true), "yes\n");
        compare(Agent.answer("confirm", false), "no\n");
        compare(Agent.answer("service", true), "yes\n");
        compare(Agent.answer("passkey", true, " 012345 "), "12345\n");
        compare(Agent.answer("passkey", true, "1234567"), null);
        compare(Agent.answer("passkey", true, "12a"), null);
        compare(Agent.answer("passkey", false), "no\n");
        compare(Agent.answer("pin", true, "0000"), "0000\n");
        compare(Agent.answer("pin", true, ""), null);
        compare(Agent.answer("pin", true, "#123"), null);
        compare(Agent.answer("pin", true, "12\nremove AA"), null);
        compare(Agent.answer("pin", true, "12345678901234567"), null);
        verify(Agent.answer("pin", false).length > 17);
    }

    function test_service_names() {
        compare(Agent.service("0000110b-0000-1000-8000-00805f9b34fb"), "audio");
        compare(Agent.service("00001124-0000-1000-8000-00805f9b34fb"), "keyboard and mouse input");
        compare(Agent.service("deadbeef"), "a bluetooth service");
    }
}
