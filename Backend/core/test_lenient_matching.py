"""Lenient matching of spoken project and people names (docs/VOICE_COMMANDS.md, "Matching")."""
from django.test import SimpleTestCase

from .capture_context import edit_distance, lenient_matches, match_people, pick_project, resolve_targets


def project(key, name, group=None, shared=False, people=()):
    return {"id": key, "name": name, "group_name": group, "shared": shared, "people": list(people)}


def names(spoken, *candidates):
    return [value for value in lenient_matches(spoken, candidates, lambda value: value)]


class EditDistanceTests(SimpleTestCase):
    def test_insertions_substitutions_and_swaps_count_once(self):
        self.assertEqual(edit_distance("pau", "paul", 1), 1)
        self.assertEqual(edit_distance("historia", "histroia", 2), 1)  # Two letters swapped.
        self.assertEqual(edit_distance("matematicas", "matematicaz", 2), 1)
        self.assertEqual(edit_distance("pol", "paul", 2), 2)
        # Beyond the limit the exact distance doesn't matter.
        self.assertEqual(edit_distance("fisica", "historia", 1), 2)
        self.assertEqual(edit_distance("a", "abcdef", 2), 3)


class ProjectMatchingTests(SimpleTestCase):
    def test_equal_ignoring_case_accents_and_the_word_project(self):
        for spoken in ("matemáticas", "MATEMATICAS", "el proyecto de Matemáticas", "la lista de matemáticas",
                       "Matemáticas project", "grupo matemáticas", "el grup de Matemáticas"):
            with self.subTest(spoken=spoken):
                self.assertEqual(names(spoken, "Matemáticas", "Física"), ["Matemáticas"])

    def test_a_unique_prefix_or_contained_word(self):
        self.assertEqual(names("mates", "Matemáticas", "Física"), ["Matemáticas"])
        self.assertEqual(names("matemática", "Matemáticas", "Física"), ["Matemáticas"])
        self.assertEqual(names("química", "Física y Química", "Música"), ["Física y Química"])
        self.assertEqual(names("la lista de la compra", "Lista de la compra", "Compras de Navidad"), ["Lista de la compra"])
        self.assertEqual(names("compras", "Lista de la compra"), ["Lista de la compra"])

    def test_two_candidates_are_never_guessed_between(self):
        self.assertEqual(names("mates", "Matemáticas", "Materiales"), ["Matemáticas", "Materiales"])
        self.assertEqual(names("fis", "Física", "Física y Química"), ["Física", "Física y Química"])

    def test_an_equal_name_wins_over_looser_matches(self):
        self.assertEqual(names("física", "Física", "Física y Química", "Música"), ["Física"])

    def test_fisica_never_becomes_musica(self):
        # Two letters apart (F, M; í, ú): a different subject, so the person is asked instead.
        self.assertEqual(names("Física", "Música"), [])
        self.assertEqual(names("fisica", "Música", "Químicas"), [])
        self.assertEqual(pick_project("Física", None, [project("music", "Música")]), (None, "project_not_available"))

    def test_matematicas_without_its_accent_is_matematicas(self):
        self.assertEqual(names("Matematicas", "Matemáticas", "Física"), ["Matemáticas"])

    def test_mates_matches_through_the_unique_prefix_rule(self):
        self.assertGreater(edit_distance("mates", "matematicas", 2), 2)  # Not a near spelling.
        self.assertEqual(names("Mates", "Matemáticas", "Física"), ["Matemáticas"])
        self.assertEqual(names("Mates", "Matemáticas", "Materiales"), ["Matemáticas", "Materiales"])

    def test_near_spellings_by_the_length_of_the_project_name(self):
        # Under 5 letters: an equal name or a prefix only.
        self.assertEqual(names("cosa", "Casa"), [])
        self.assertEqual(names("arta", "Arte"), [])
        # 5 to 9 letters: one letter.
        self.assertEqual(names("Quimca", "Química"), ["Química"])
        self.assertEqual(names("Kimica", "Química"), [])
        self.assertEqual(names("histroia", "Historia", "Química"), ["Historia"])  # Two letters swapped count once.
        for said, other in (("Historia", "Victoria"), ("Biología", "Geología"), ("Economía", "Ecología")):
            with self.subTest(said=said):
                self.assertEqual(names(said, other), [])  # Two letters apart at 8 letters: another subject.
        # From 10 letters: two letters.
        self.assertEqual(names("Matemátcas", "Matemáticas"), ["Matemáticas"])
        self.assertEqual(names("Matemtcas", "Matemáticas"), ["Matemáticas"])
        self.assertEqual(names("Matmtcas", "Matemáticas"), [])
        # The limit is the project name's own: a longer phrase doesn't widen it.
        self.assertEqual(names("historiaas", "Historia"), [])

    def test_a_near_spelling_is_never_picked_when_another_project_is_near_or_named(self):
        self.assertEqual(names("Histria", "Historia", "Histeria"), ["Historia", "Histeria"])
        self.assertEqual(pick_project("Histria", None, [project("history", "Historia"), project("hysteria", "Histeria")]),
                         (None, "ambiguous_project"))
        # The words hold another project's full name: that one, never a near spelling of the other.
        self.assertEqual(names("Inglés y Matemátcas", "Inglés", "Matemáticas"), ["Inglés"])
        self.assertEqual(names("mi Matemátcas", "Mi", "Matemáticas"), [])
        self.assertEqual(names("Matemátcas", "Mi", "Matemáticas"), ["Matemáticas"])

    def test_nothing_like_it(self):
        self.assertEqual(names("Secret project", "Física", "Languages", "Máster"), [])
        self.assertEqual(names("el proyecto", "Física"), [])
        self.assertEqual(names("", "Física"), [])

    def test_pick_project_reports_ambiguity_and_absence(self):
        projects = [project("maths", "Matemáticas"), project("materials", "Materiales"), project("art", "Arte")]
        self.assertEqual(pick_project("arte", None, projects), (projects[2], None))
        self.assertEqual(pick_project("mates", None, projects), (None, "ambiguous_project"))
        self.assertEqual(pick_project("Química", None, projects), (None, "project_not_available"))

    def test_a_group_name_finds_its_only_project(self):
        projects = [project("songs", "Canciones", group="Coro", shared=True),
                    project("algebra", "Álgebra", group="Máster", shared=True),
                    project("geometry", "Geometría", group="Máster", shared=True)]
        self.assertEqual(pick_project("el grupo Coro", None, projects)[0]["id"], "songs")
        self.assertEqual(pick_project("master", None, projects), (None, "ambiguous_project"))
        self.assertEqual(pick_project("algebra", "master", projects)[0]["id"], "algebra")
        self.assertEqual(pick_project(None, "coro", projects)[0]["id"], "songs")
        self.assertEqual(pick_project("algebra", "coro", projects), (None, "project_not_available"))

    def test_resolve_targets_uses_lenient_matching_for_tasks(self):
        context = {"user_id": 1, "default_project_id": None, "projects": [
            project("maths", "Matemáticas", shared=True, people=[{"user_id": 1, "name": "Miki", "voice_name": ""},
                                                                  {"user_id": 3, "name": "Paul Serra", "voice_name": ""}])]}
        draft = resolve_targets({"title": "Repasar", "project_name": "mates", "member_name": "Pau",
                                 "assignment_request": "member"}, context)
        self.assertEqual((draft["list_id"], draft["assignee_id"], draft["assignment"]), ("maths", 3, "member"))
        self.assertEqual(draft["assignment_issues"], [])
        self.assertNotIn("new_project", draft)  # Only drafts for apps with commands have it.


class PeopleMatchingTests(SimpleTestCase):
    def setUp(self):
        self.people = [{"user_id": 1, "name": "Miki", "voice_name": ""},
                       {"user_id": 2, "name": "Ana García", "voice_name": "Anita"},
                       {"user_id": 3, "name": "Paul", "voice_name": ""},
                       {"user_id": 4, "name": "Jordi Puig", "voice_name": "Pol"}]

    def ids(self, spoken, people=None):
        return [person["user_id"] for person in match_people(spoken, self.people if people is None else people)]

    def test_todays_rules(self):
        self.assertEqual(self.ids("ana"), [2])
        self.assertEqual(self.ids("Ana García"), [2])
        self.assertEqual(self.ids("anita"), [2])
        self.assertEqual(self.ids("POL"), [4])

    def test_a_first_name_or_voice_name_one_letter_away(self):
        self.assertEqual(self.ids("Pau"), [3])
        self.assertEqual(self.ids("Anitta"), [2])
        self.assertEqual(self.ids("Ana Garsia"), [2])
        self.assertEqual(self.ids("Jordy"), [4])

    def test_never_picks_between_two(self):
        people = self.people + [{"user_id": 5, "name": "Pau Vidal", "voice_name": ""}]
        self.assertEqual(self.ids("Pau", people), [5])  # The exact first name wins.
        # Paul, Pau and the voice name Pol are all one letter away.
        self.assertEqual(self.ids("Pal", people), [3, 4, 5])

    def test_too_short_or_too_far(self):
        self.assertEqual(self.ids("Al"), [])
        self.assertEqual(self.ids("Pablo"), [])
        self.assertEqual(self.ids(""), [])
        # The same person in two projects is one person.
        self.assertEqual(self.ids("Paul", self.people + [self.people[2]]), [3])
