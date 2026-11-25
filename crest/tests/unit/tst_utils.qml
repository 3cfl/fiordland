import QtQuick
import QtTest
import "../../utils/calc.js" as Calc
import "../../utils/fuzzy.js" as Fuzzy

TestCase {
    name: "utils"

    function test_calc_basic() {
        compare(Calc.evaluate("2+2"), "4");
        compare(Calc.evaluate("2+3*4"), "14");
        compare(Calc.evaluate("(2+3)*4"), "20");
        compare(Calc.evaluate("2^3^2"), "512");
        compare(Calc.evaluate("2^-1"), "0.5");
        compare(Calc.evaluate("-3^2"), "-9");
        compare(Calc.evaluate("10/4"), "2.5");
        compare(Calc.evaluate("5!"), "120");
        compare(Calc.evaluate("sqrt(16)+1"), "5");
        compare(Calc.evaluate("2pi"), String(parseFloat((2 * Math.PI).toPrecision(12))));
        compare(Calc.evaluate("max(3, 9, 4)"), "9");
        compare(Calc.evaluate("7 × 6"), "42");
        compare(Calc.evaluate("0.1+0.2"), "0.3");
        compare(Calc.evaluate("=3*3"), "9");
    }

    function test_calc_rejects() {
        compare(Calc.evaluate("firefox"), null);
        compare(Calc.evaluate("42"), null);
        compare(Calc.evaluate("=42"), null);
        compare(Calc.evaluate("42", true), "42");
        compare(Calc.evaluate("1/0"), null);
        compare(Calc.evaluate("2+"), null);
        compare(Calc.evaluate("alert(1)"), null);
        compare(Calc.evaluate("constructor"), null);
        compare(Calc.evaluate("toString(1)"), null);
        compare(Calc.evaluate(""), null);
    }

    function test_fuzzy_order() {
        verify(Fuzzy.score("fire", "Firefox") > Fuzzy.score("fire", "Wildfire"));
        verify(Fuzzy.score("ff", "Firefox") > 0);
        verify(Fuzzy.score("zz", "Firefox") < 0);
        verify(Fuzzy.score("term", "Terminal") > Fuzzy.score("tml", "Terminal"));
        const items = ["Thunar", "Firefox", "Files", "kitty"];
        const ranked = Fuzzy.rank(items, "fi", [[s => s, 1]], 10).map(r => r.item);
        compare(ranked[0], "Files");
        compare(ranked.indexOf("kitty"), -1);
        compare(Fuzzy.rank(items, "", [[s => s, 1]], 2).length, 2);
    }
}
