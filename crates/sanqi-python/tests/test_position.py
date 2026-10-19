import unittest

import sanqi_python as sanqi


class PositionTests(unittest.TestCase):
    def test_move_and_copy(self):
        position = sanqi.Position.initial()
        original = position.copy()
        move = position.legal_moves()[0]
        self.assertTrue(position.is_legal_move(move))
        self.assertEqual(sanqi.parse_move_string(move), move)
        position.apply_move(move)
        self.assertEqual(position.side_to_move(), "black")
        self.assertEqual(original.side_to_move(), "white")
        self.assertNotEqual(position.ascii_board(), original.ascii_board())

    def test_analysis(self):
        position = sanqi.initial_position()
        analysis = position.analyze(1)
        self.assertIsNotNone(analysis)
        self.assertIn(analysis["best_move"], position.legal_moves())
        self.assertIsInstance(analysis["score"], int)
        self.assertEqual(analysis["depth"], 1)
        self.assertEqual(analysis["principal_variation"][0], analysis["best_move"])
        timed = position.analyze_timed(1, 1000)
        self.assertIn(timed["best_move"], position.legal_moves())

    def test_rendering_and_pivots(self):
        position = sanqi.Position.initial()
        move = position.legal_moves()[0]
        self.assertIn("<svg", position.svg_board())
        self.assertIn("<svg", position.svg_for_move(move))
        pivots = position.supporting_pivots(move)
        self.assertTrue(pivots)
        self.assertEqual(len(pivots[0]["supports"]), 2)

    def test_invalid_input(self):
        position = sanqi.Position.initial()
        with self.assertRaises(ValueError):
            sanqi.Position.empty("invalid")
        with self.assertRaises(ValueError):
            position.apply_move("invalid")
        with self.assertRaises(ValueError):
            position.piece_at("z9")


if __name__ == "__main__":
    unittest.main()
