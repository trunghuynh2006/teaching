-- =============================================================================
-- seed_java_domain.sql — Domain tree + concepts for Java programming
--
-- Hierarchy:
--   mathematics
--   logic                    → mathematics
--   computer science         → mathematics, logic
--   software engineering     → computer science
--   programming              → software engineering
--   object-oriented prog.    → programming
--   java programming         → programming, object-oriented programming
--
-- Safe to re-run: all inserts use ON CONFLICT DO NOTHING.
-- Parent concept links are set via UPDATE after all concepts are inserted.
-- =============================================================================

-- ── 1. Domains ────────────────────────────────────────────────────────────────

INSERT INTO domains (id, name, description, created_by, updated_by) VALUES
  ('dom_math',  'mathematics',                  'The study of numbers, quantities, shapes, and logical structure.', 'seed', 'seed'),
  ('dom_logic', 'logic',                         'The study of correct reasoning, inference rules, and formal proof.', 'seed', 'seed'),
  ('dom_cs',    'computer science',              'The study of computation, algorithms, data structures, and the theory of programming.', 'seed', 'seed'),
  ('dom_se',    'software engineering',          'The disciplined application of engineering principles to the design, development, and maintenance of software.', 'seed', 'seed'),
  ('dom_prog',  'programming',                   'The craft of expressing computations as executable instructions in a programming language.', 'seed', 'seed'),
  ('dom_oop',   'object-oriented programming',   'A programming paradigm that organises code into objects combining state and behaviour.', 'seed', 'seed'),
  ('dom_java',  'java programming',              'Programming using the Java language, its standard library, and the JVM platform.', 'seed', 'seed')
ON CONFLICT (name) DO NOTHING;

-- ── 2. Domain parent-child relationships ──────────────────────────────────────

INSERT INTO domain_prerequisites (domain, prerequisite, created_by) VALUES
  ('logic',                        'mathematics',                'seed'),
  ('computer science',             'mathematics',                'seed'),
  ('computer science',             'logic',                      'seed'),
  ('software engineering',         'computer science',           'seed'),
  ('programming',                  'software engineering',       'seed'),
  ('object-oriented programming',  'programming',                'seed'),
  ('java programming',             'programming',                'seed'),
  ('java programming',             'object-oriented programming','seed')
ON CONFLICT DO NOTHING;

-- ── 3. Concepts (pass 1: insert all without parent links) ────────────────────

INSERT INTO concepts (id, canonical_name, domain, description, example, analogy, common_mistakes, tags, level, scope, created_by, updated_by) VALUES

-- ── Mathematics ──────────────────────────────────────────────────────────────
  ('con_math_var',
   'Variable',
   'mathematics',
   'A symbol that represents an unknown or changeable quantity in a mathematical expression.',
   'In the equation x + 3 = 7, x is a variable with value 4.',
   'A variable is like an empty labelled envelope — the label stays the same but what is inside can change.',
   'Confusing a variable with a fixed constant, or assuming a variable can only hold numbers.',
   ARRAY['algebra','symbol','quantity'], 'foundation', 'universal', 'seed', 'seed'),

  ('con_math_func',
   'Function',
   'mathematics',
   'A relation that maps every element of one set (the domain) to exactly one element of another set (the codomain).',
   'f(x) = x² maps 3 → 9 and −3 → 9; each input has exactly one output.',
   'A function is like a vending machine — put in a specific coin and you always get the same snack back.',
   'Thinking a relation is a function when one input maps to multiple outputs, or confusing the domain with the range.',
   ARRAY['mapping','relation','input-output'], 'foundation', 'universal', 'seed', 'seed'),

  ('con_math_set',
   'Set',
   'mathematics',
   'An unordered collection of distinct objects, called elements, treated as a single entity.',
   '{1, 2, 3} is a set of three integers; {1, 2, 2, 3} is still {1, 2, 3} because sets have no duplicates.',
   'A set is like a bag of unique marbles — the order they were put in does not matter, and you cannot have two identical ones.',
   'Assuming sets are ordered, or forgetting that duplicate elements are automatically collapsed into one.',
   ARRAY['collection','elements','membership'], 'foundation', 'universal', 'seed', 'seed'),

  ('con_math_algo',
   'Algorithm',
   'mathematics',
   'A finite, ordered sequence of unambiguous steps that solves a problem or computes a result.',
   'Euclid''s algorithm repeatedly divides two numbers to find their greatest common divisor.',
   'An algorithm is like a recipe — a precise list of steps anyone can follow to produce the same result.',
   'Confusing an algorithm with a program, or writing steps that are ambiguous and cannot be followed mechanically.',
   ARRAY['steps','procedure','computation'], 'foundation', 'universal', 'seed', 'seed'),

  ('con_math_bool',
   'Boolean algebra',
   'mathematics',
   'An algebraic system dealing with variables that take only two values — true and false — and operations AND, OR, NOT.',
   'NOT (A AND B) = (NOT A) OR (NOT B) is De Morgan''s law, used to simplify logic circuits.',
   'Boolean algebra is like a light-switch system — every switch is either on or off, and you combine them with "all on", "any on", or "flip".',
   'Mixing up precedence (AND binds tighter than OR) or forgetting that double negation cancels out.',
   ARRAY['logic','true-false','AND','OR','NOT'], 'intermediate', 'universal', 'seed', 'seed'),

  ('con_math_proof',
   'Mathematical Proof',
   'mathematics',
   'A rigorous, step-by-step logical argument that establishes the truth of a mathematical statement from axioms and previously proven results.',
   'Proof by induction: show P(1) is true, then show P(k)→P(k+1), to prove P(n) for all n.',
   'A proof is like a chain of dominoes — each piece knocks over the next, and the whole chain only works if every link is solid.',
   'Assuming what you are trying to prove (circular reasoning), or treating a few examples as a complete proof.',
   ARRAY['reasoning','induction','axioms'], 'intermediate', 'universal', 'seed', 'seed'),

-- ── Logic ─────────────────────────────────────────────────────────────────────
  ('con_logic_prop',
   'Proposition',
   'logic',
   'A declarative statement that is either true or false, but not both.',
   '"Java is compiled to bytecode" is a true proposition; "x > 5" is not a proposition because x is unspecified.',
   'A proposition is like a coin — it has exactly one face showing at any time: heads (true) or tails (false).',
   'Treating questions or commands as propositions, or confusing a proposition with a predicate that contains a free variable.',
   ARRAY['statement','truth-value','declarative'], 'foundation', 'universal', 'seed', 'seed'),

  ('con_logic_boolexpr',
   'Boolean Expression',
   'logic',
   'A combination of boolean values and logical operators (AND, OR, NOT) that evaluates to true or false.',
   '(age >= 18) AND (hasID == true) evaluates to true only when both conditions hold.',
   'A boolean expression is like a checklist of conditions — the whole checklist passes only if the right combination of items are ticked.',
   'Short-circuit evaluation surprises: in A && B, if A is false, B is never evaluated, which matters if B has side effects.',
   ARRAY['AND','OR','NOT','condition'], 'foundation', 'universal', 'seed', 'seed'),

  ('con_logic_cond',
   'Conditional Statement',
   'logic',
   'A logical statement of the form "If P then Q", asserting that whenever P is true, Q must also be true.',
   'If a number is divisible by 4, then it is divisible by 2 — true; but the converse is not guaranteed.',
   'A conditional is like an umbrella rule: "If it rains, carry an umbrella." It says nothing about what happens when it does not rain.',
   'Confusing the conditional with its converse (If Q then P) or thinking a false antecedent makes the whole statement false.',
   ARRAY['if-then','implication','antecedent','consequent'], 'foundation', 'universal', 'seed', 'seed'),

  ('con_logic_pred',
   'Predicate',
   'logic',
   'A statement containing one or more variables that becomes a proposition when the variables are replaced with specific values.',
   'P(x): "x is prime" is a predicate; P(7) is true, P(4) is false.',
   'A predicate is like a template for a statement with blanks to fill in — only when you fill in the blanks does it become true or false.',
   'Treating a predicate as a proposition without substituting values, or confusing predicate logic with boolean algebra.',
   ARRAY['variable','predicate-logic','quantifier'], 'intermediate', 'universal', 'seed', 'seed'),

  ('con_logic_truth',
   'Truth Table',
   'logic',
   'A table listing all possible combinations of truth values for the variables of a logical expression and the resulting value of the expression.',
   'The truth table for A AND B has 4 rows (TT→T, TF→F, FT→F, FF→F).',
   'A truth table is like a complete instruction manual — it exhaustively covers every scenario so there is no ambiguity.',
   'Forgetting to list all 2ⁿ combinations for n variables, or making errors in evaluating compound expressions row by row.',
   ARRAY['truth-value','enumeration','logic-gate'], 'foundation', 'universal', 'seed', 'seed'),

-- ── Computer Science ──────────────────────────────────────────────────────────
  ('con_cs_algo',
   'Algorithm',
   'computer science',
   'A precise, finite sequence of steps a computer can execute to solve a problem or transform data.',
   'Binary search halves the search space each step, finding a value in O(log n) comparisons.',
   'A computer algorithm is like a GPS route — a step-by-step path from start to destination that a machine follows exactly.',
   'Writing algorithms that are correct but not efficient, or forgetting to handle edge cases like empty input.',
   ARRAY['problem-solving','steps','efficiency'], 'foundation', 'universal', 'seed', 'seed'),

  ('con_cs_ds',
   'Data Structure',
   'computer science',
   'A way of organising and storing data in a computer so that it can be accessed and modified efficiently.',
   'A linked list stores each element alongside a pointer to the next, allowing O(1) insertion at the head but O(n) random access.',
   'A data structure is like a filing system — a drawer of folders (array) is fast to open by number but slow to insert into the middle; a stack of papers (stack) is only fast at the top.',
   'Choosing a data structure by familiarity rather than by the operations needed — using a list when a set or map would be far more efficient.',
   ARRAY['array','list','tree','map','organisation'], 'foundation', 'universal', 'seed', 'seed'),

  ('con_cs_abs',
   'Abstraction',
   'computer science',
   'The process of hiding implementation details and exposing only the relevant interface, reducing complexity.',
   'You call list.sort() without knowing whether it uses Timsort or quicksort internally.',
   'Abstraction is like driving a car — you use the steering wheel and pedals without understanding the combustion engine.',
   'Leaking implementation details through the abstraction boundary, or creating abstractions so general they are useless.',
   ARRAY['interface','hiding','complexity','layers'], 'foundation', 'universal', 'seed', 'seed'),

  ('con_cs_rec',
   'Recursion',
   'computer science',
   'A technique where a function calls itself with a smaller or simpler input until it reaches a base case.',
   'factorial(n) = n * factorial(n-1), with factorial(0) = 1 as the base case.',
   'Recursion is like looking up a word in a dictionary that says "see: word" — eventually you reach a definition that does not refer back.',
   'Forgetting the base case (causing infinite recursion), or using recursion where a simple loop is clearer and more efficient.',
   ARRAY['self-reference','base-case','call-stack'], 'intermediate', 'universal', 'seed', 'seed'),

  ('con_cs_complex',
   'Time Complexity',
   'computer science',
   'A measure of how the running time of an algorithm grows relative to the size of its input, expressed using Big-O notation.',
   'A single loop over n elements is O(n); a nested loop is O(n²); binary search is O(log n).',
   'Time complexity is like predicting travel time — O(n) is like walking (scales linearly with distance), O(log n) is like flying direct.',
   'Confusing worst-case with average-case complexity, or optimising code without profiling to find the actual bottleneck.',
   ARRAY['Big-O','performance','scalability'], 'intermediate', 'universal', 'seed', 'seed'),

  ('con_cs_mem',
   'Memory Management',
   'computer science',
   'The process of allocating and freeing memory during program execution to store data and prevent leaks.',
   'In C, malloc() reserves heap memory and free() releases it; forgetting free() causes a memory leak.',
   'Memory management is like renting storage units — you must book one before storing anything, and return it when done or you keep paying.',
   'Forgetting to free memory (leaks), freeing the same memory twice (double free), or reading from already-freed memory.',
   ARRAY['heap','stack','allocation','garbage-collection'], 'intermediate', 'universal', 'seed', 'seed'),

-- ── Software Engineering ──────────────────────────────────────────────────────
  ('con_se_pattern',
   'Design Pattern',
   'software engineering',
   'A reusable, named solution to a commonly occurring problem in software design.',
   'The Singleton pattern ensures only one instance of a class exists, e.g. a database connection pool.',
   'A design pattern is like an architectural blueprint — not a finished building, but a proven plan you can adapt to your site.',
   'Forcing a pattern onto a problem that does not fit it (pattern over-engineering), or applying patterns without understanding the tradeoffs.',
   ARRAY['architecture','reuse','OOP','GoF'], 'intermediate', 'universal', 'seed', 'seed'),

  ('con_se_test',
   'Unit Testing',
   'software engineering',
   'Testing individual units of code (functions or classes) in isolation to verify they behave correctly.',
   'A test asserts that add(2, 3) == 5 and that add(-1, 1) == 0, covering both normal and edge cases.',
   'A unit test is like a quality-control check on a single factory part before it is assembled — catching defects early is cheaper than recalling the finished product.',
   'Testing only the happy path and ignoring edge cases, or writing tests so tightly coupled to implementation that they break during refactoring.',
   ARRAY['testing','TDD','assertion','isolation'], 'foundation', 'universal', 'seed', 'seed'),

  ('con_se_debug',
   'Debugging',
   'software engineering',
   'The process of finding, understanding, and fixing defects in code.',
   'Setting a breakpoint before a crash and inspecting variable values reveals that an index is off by one.',
   'Debugging is like being a detective — you gather clues (logs, stack traces), form a hypothesis, test it, and repeat until the culprit is found.',
   'Changing multiple things at once so you cannot tell which fix worked, or fixing symptoms without understanding the root cause.',
   ARRAY['bug','breakpoint','logs','root-cause'], 'foundation', 'universal', 'seed', 'seed'),

  ('con_se_vcs',
   'Version Control',
   'software engineering',
   'A system that records changes to files over time so that you can recall specific versions later and collaborate safely.',
   'git commit -m "fix login bug" saves a snapshot; git revert undoes it without erasing history.',
   'Version control is like tracked changes in a document — every edit is recorded, who made it and when, and you can roll back to any earlier state.',
   'Committing directly to the main branch without review, writing meaningless commit messages, or not committing frequently enough.',
   ARRAY['git','commit','branch','collaboration'], 'foundation', 'universal', 'seed', 'seed'),

  ('con_se_refactor',
   'Refactoring',
   'software engineering',
   'Restructuring existing code to improve its internal quality without changing its external behaviour.',
   'Extracting a repeated 30-line block into a named function makes the code shorter and its intent clearer.',
   'Refactoring is like reorganising a toolbox — you do not add or remove tools, you just arrange them so the right one is always easy to find.',
   'Refactoring without tests (so regressions go unnoticed), or conflating refactoring with adding new features in the same commit.',
   ARRAY['clean-code','readability','maintenance'], 'intermediate', 'universal', 'seed', 'seed'),

  ('con_se_api',
   'API',
   'software engineering',
   'An Application Programming Interface — a defined contract of inputs, outputs, and behaviour that one component exposes for others to use.',
   'GitHub''s REST API accepts GET /repos/{owner}/{repo} and returns a JSON object describing the repository.',
   'An API is like a restaurant menu — it tells you what you can order and what you will get, without revealing how the kitchen works.',
   'Changing a public API without versioning (breaking clients), or designing an API around internal implementation rather than the caller''s needs.',
   ARRAY['interface','contract','REST','library'], 'intermediate', 'universal', 'seed', 'seed'),

-- ── Programming ───────────────────────────────────────────────────────────────
  ('con_prog_var',
   'Variable',
   'programming',
   'A named location in memory that stores a value which can be read or changed during program execution.',
   'int count = 0; count = count + 1; — count now holds 1.',
   'A variable is like a labelled sticky note on a whiteboard — you write a value on it, can read it any time, and can erase and rewrite it.',
   'Confusing variable assignment (=) with equality comparison (== or ===), or using a variable before initialising it.',
   ARRAY['storage','name','value','assignment'], 'foundation', 'universal', 'seed', 'seed'),

  ('con_prog_type',
   'Data Type',
   'programming',
   'A classification that specifies what kind of value a variable holds and what operations are valid on it.',
   'An int holds whole numbers and supports arithmetic; a String holds text and supports concatenation but not division.',
   'A data type is like a container shape — a round hole only accepts round pegs; mixing types causes errors just as mixing container shapes jams the assembly line.',
   'Assuming numeric strings are numbers (e.g. "5" + 1 giving "51" in JavaScript), or not accounting for integer overflow.',
   ARRAY['int','string','boolean','type-safety'], 'foundation', 'universal', 'seed', 'seed'),

  ('con_prog_flow',
   'Control Flow',
   'programming',
   'The order in which individual statements, instructions, or function calls are executed in a program.',
   'if (score >= 60) { pass() } else { fail() } — execution branches depending on the value of score.',
   'Control flow is like a flowchart — arrows show which box you go to next, and diamonds represent decisions that split the path.',
   'Forgetting that code after a return statement is unreachable, or creating deeply nested conditions that are hard to follow.',
   ARRAY['if-else','branching','switch','conditions'], 'foundation', 'universal', 'seed', 'seed'),

  ('con_prog_loop',
   'Loop',
   'programming',
   'A control structure that repeats a block of code while a condition is true or for a set number of iterations.',
   'for (int i = 0; i < 10; i++) { System.out.println(i); } prints 0 through 9.',
   'A loop is like a revolving door — you keep going round until a condition (someone holds it open) tells you to stop.',
   'Off-by-one errors (iterating one too many or too few times), and forgetting to update the loop variable, causing an infinite loop.',
   ARRAY['for','while','iteration','repetition'], 'foundation', 'universal', 'seed', 'seed'),

  ('con_prog_func',
   'Function',
   'programming',
   'A named, reusable block of code that takes inputs (parameters), performs a task, and optionally returns a value.',
   'int square(int n) { return n * n; } — calling square(5) returns 25.',
   'A function is like a recipe card — name it, list the ingredients (parameters), follow the steps, and get the dish (return value).',
   'Forgetting to return a value when one is expected, or writing functions so long they do too many things (violating single responsibility).',
   ARRAY['reuse','parameter','return','call'], 'foundation', 'universal', 'seed', 'seed'),

  ('con_prog_rec',
   'Recursion',
   'programming',
   'A programming technique where a function calls itself to solve a smaller version of the same problem.',
   'int fib(int n) { if (n <= 1) return n; return fib(n-1) + fib(n-2); }',
   'Recursion is like looking in a mirror held in front of another mirror — the image repeats, getting smaller, until it disappears.',
   'Missing or incorrectly implementing the base case (causing a StackOverflowError), or using recursion on problems where iteration is simpler.',
   ARRAY['self-call','base-case','stack','divide-and-conquer'], 'intermediate', 'universal', 'seed', 'seed'),

  ('con_prog_arr',
   'Array',
   'programming',
   'An ordered, fixed-size collection of elements of the same type, accessed by integer index starting at 0.',
   'int[] scores = {90, 85, 78}; scores[0] is 90, scores[2] is 78.',
   'An array is like a row of numbered lockers — each locker holds one item and you access it instantly by its number.',
   'Accessing an index outside the array bounds (ArrayIndexOutOfBoundsException), or forgetting that indices start at 0 not 1.',
   ARRAY['index','collection','fixed-size','zero-based'], 'foundation', 'universal', 'seed', 'seed'),

  ('con_prog_str',
   'String',
   'programming',
   'A sequence of characters used to represent text, typically immutable once created.',
   '"Hello" + ", " + "world!" produces "Hello, world!" via concatenation.',
   'A string is like a sentence written on a strip of paper — you can read it, copy it, or cut pieces out, but you cannot change the original strip in place.',
   'Comparing strings with == instead of .equals() in Java (comparing references, not content), or repeatedly concatenating strings in a loop (use StringBuilder).',
   ARRAY['text','characters','immutable','concatenation'], 'foundation', 'universal', 'seed', 'seed'),

  ('con_prog_null',
   'Null Value',
   'programming',
   'A special value representing the intentional absence of any object or valid value.',
   'String name = null; name.length() throws a NullPointerException because null has no methods.',
   'Null is like an empty delivery slot — the slot exists, but there is nothing in it; trying to open the parcel crashes the process.',
   'Not checking for null before using a reference (NullPointerException), or overusing null where an Optional or empty collection would be clearer.',
   ARRAY['absence','null-pointer','optional'], 'foundation', 'universal', 'seed', 'seed'),

  ('con_prog_exc',
   'Exception Handling',
   'programming',
   'A mechanism to detect, signal, and recover from errors or unexpected conditions during program execution.',
   'try { int result = 10 / 0; } catch (ArithmeticException e) { System.out.println("Cannot divide by zero"); }',
   'Exception handling is like a safety net under a trapeze — normal execution soars through the air, but if something goes wrong the net catches you before you hit the ground.',
   'Catching overly broad exceptions (catch Exception) hiding bugs, swallowing exceptions silently, or using exceptions for normal control flow.',
   ARRAY['try-catch','error','runtime','robustness'], 'intermediate', 'universal', 'seed', 'seed'),

-- ── Object-Oriented Programming ───────────────────────────────────────────────
  ('con_oop_class',
   'Class',
   'object-oriented programming',
   'A blueprint that defines the structure (fields) and behaviour (methods) that its instances (objects) will have.',
   'class Dog { String name; void bark() { System.out.println("Woof"); } } defines what every Dog object looks like.',
   'A class is like an architectural blueprint — it describes the building, but you need to construct (instantiate) it to get an actual house.',
   'Putting too much responsibility in one class (God Object), or confusing the class itself with an instance of it.',
   ARRAY['blueprint','type','fields','methods'], 'foundation', 'universal', 'seed', 'seed'),

  ('con_oop_obj',
   'Object',
   'object-oriented programming',
   'A runtime instance of a class, combining its own state (field values) and the behaviour defined by the class.',
   'Dog rex = new Dog(); rex.name = "Rex"; rex.bark(); — rex is one object; Dog is the class.',
   'An object is like an actual house built from a blueprint — it occupies real space, has its own address, and you can live in it.',
   'Confusing object identity (two variables pointing to the same object) with object equality (two objects with the same field values).',
   ARRAY['instance','state','identity','new'], 'foundation', 'universal', 'seed', 'seed'),

  ('con_oop_enc',
   'Encapsulation',
   'object-oriented programming',
   'Bundling data (fields) and the methods that operate on that data inside a class, and restricting direct external access.',
   'Making balance private and exposing only deposit() and withdraw() prevents external code from setting an arbitrary balance.',
   'Encapsulation is like a pill capsule — the active ingredient (data) is sealed inside; you interact with it through its surface (public methods), not by tearing it open.',
   'Making all fields public for convenience, destroying encapsulation, or writing getters/setters for every field without thinking about what should truly be hidden.',
   ARRAY['private','public','getter','setter','hiding'], 'foundation', 'universal', 'seed', 'seed'),

  ('con_oop_inh',
   'Inheritance',
   'object-oriented programming',
   'A mechanism where a subclass acquires the fields and methods of a superclass, enabling code reuse and an "is-a" relationship.',
   'class Cat extends Animal — Cat inherits eat() and sleep() from Animal and can add its own purr() method.',
   'Inheritance is like a family tree — children inherit traits from parents but can also develop their own unique characteristics.',
   'Using inheritance purely for code reuse when there is no genuine is-a relationship (prefer composition), or creating deep inheritance chains that are hard to follow.',
   ARRAY['extends','superclass','subclass','is-a','override'], 'intermediate', 'universal', 'seed', 'seed'),

  ('con_oop_poly',
   'Polymorphism',
   'object-oriented programming',
   'The ability of different classes to be treated as instances of a common supertype, with method calls resolving to the correct implementation at runtime.',
   'Animal a = new Dog(); a.speak(); calls Dog''s speak(), not Animal''s — the actual type determines the method, not the declared type.',
   'Polymorphism is like a universal remote — the "play" button works on a TV, DVD player, or streaming box, each responding in its own way.',
   'Confusing compile-time overloading (same method name, different parameters) with runtime overriding (same signature in subclass).',
   ARRAY['override','runtime','dispatch','interface','liskov'], 'intermediate', 'universal', 'seed', 'seed'),

  ('con_oop_iface',
   'Interface',
   'object-oriented programming',
   'A contract specifying a set of methods a class must implement, with no implementation details — defining what, not how.',
   'interface Drawable { void draw(); } — any class implementing Drawable must provide a draw() method.',
   'An interface is like a job description — it lists the responsibilities required, but does not say how the person hired will fulfil them.',
   'Confusing an interface with an abstract class, or creating fat interfaces with too many methods that force implementors to provide irrelevant stubs.',
   ARRAY['contract','implements','abstraction','decoupling'], 'intermediate', 'universal', 'seed', 'seed'),

  ('con_oop_abs',
   'Abstract Class',
   'object-oriented programming',
   'A class that cannot be instantiated directly, providing partial implementation and declaring abstract methods that subclasses must complete.',
   'abstract class Shape { abstract double area(); double perimeter() { return 0; } } — area() is left to subclasses.',
   'An abstract class is like a partially assembled kit — the manufacturer has done the common work, but you must finish the custom parts yourself.',
   'Choosing abstract class over interface when the class has no shared state, or forgetting that a subclass must implement all abstract methods or itself be abstract.',
   ARRAY['abstract','partial-implementation','extends','template'], 'intermediate', 'universal', 'seed', 'seed'),

  ('con_oop_ctor',
   'Constructor',
   'object-oriented programming',
   'A special method called when an object is created, used to initialise its fields to a valid starting state.',
   'class Point { int x, y; Point(int x, int y) { this.x = x; this.y = y; } } — new Point(3,4) sets x=3, y=4.',
   'A constructor is like the setup phase of a board game — before play begins you arrange all the pieces in their correct starting positions.',
   'Doing heavy work (network calls, file I/O) inside a constructor, making object creation slow and hard to test.',
   ARRAY['initialise','new','this','overloading'], 'foundation', 'universal', 'seed', 'seed'),

  ('con_oop_override',
   'Method Overriding',
   'object-oriented programming',
   'Providing a new implementation of a method in a subclass that has the same signature as in the superclass.',
   '@Override public String toString() { return "Dog[name=" + name + "]"; } replaces Object''s default toString().',
   'Overriding is like a cover version of a song — same title and structure, but the artist performs it their own way.',
   'Forgetting @Override (so a typo creates a new method instead of overriding), or changing the method signature which creates overloading, not overriding.',
   ARRAY['@Override','runtime-dispatch','polymorphism','super'], 'intermediate', 'universal', 'seed', 'seed'),

-- ── Java Programming ──────────────────────────────────────────────────────────
  ('con_java_jvm',
   'Java Virtual Machine',
   'java programming',
   'An abstract computing machine that executes Java bytecode, providing platform independence and runtime services like garbage collection.',
   'javac Hello.java produces Hello.class (bytecode); java Hello runs it on any JVM regardless of OS.',
   'The JVM is like a universal translator — Java code is compiled once into a neutral language (bytecode), and the JVM translates it to native instructions wherever it runs.',
   'Confusing the JVM with the JDK or JRE, or assuming all JVMs behave identically (implementations vary in GC and JIT behaviour).',
   ARRAY['bytecode','platform-independence','JDK','JRE','runtime'], 'foundation', 'framework-specific', 'seed', 'seed'),

  ('con_java_main',
   'Main Method',
   'java programming',
   'The entry point of a Java application: public static void main(String[] args), called by the JVM to start execution.',
   'public static void main(String[] args) { System.out.println("Hello"); } — run with java ClassName.',
   'The main method is like the front door of a building — it is the designated entry point; everything else is accessed from inside.',
   'Misspelling the signature (e.g. Main instead of main, or wrong parameter type) causing a "Main method not found" error at runtime.',
   ARRAY['entry-point','static','args','startup'], 'foundation', 'framework-specific', 'seed', 'seed'),

  ('con_java_static',
   'Static Keyword',
   'java programming',
   'Declares that a member belongs to the class itself rather than to any instance, shared across all objects.',
   'static int count = 0; in a class is one shared counter; each new instance does not get its own copy.',
   'Static is like a notice board in an office — it belongs to the building, not any individual employee; everyone reads and writes the same board.',
   'Accessing instance fields from a static method (compile error), or overusing static to avoid understanding object-oriented design.',
   ARRAY['class-level','shared','static-method','singleton'], 'intermediate', 'framework-specific', 'seed', 'seed'),

  ('con_java_prim',
   'Primitive Types',
   'java programming',
   'The eight built-in value types in Java (int, long, double, float, boolean, char, byte, short) stored directly on the stack, not as objects.',
   'int x = 5; occupies 32 bits on the stack; Integer y = 5; is a heap-allocated object wrapping the same value.',
   'Primitives are like physical cash — lightweight, fast to use, kept in your pocket (stack), unlike cheques (objects) that require bank processing.',
   'Forgetting that primitives cannot be null (use their wrapper types instead), or integer overflow when arithmetic exceeds the type''s range.',
   ARRAY['int','double','boolean','char','value-type','stack'], 'foundation', 'framework-specific', 'seed', 'seed'),

  ('con_java_autobox',
   'Autoboxing',
   'java programming',
   'Java''s automatic conversion between primitive types and their corresponding wrapper objects (e.g. int ↔ Integer).',
   'List<Integer> list = new ArrayList<>(); list.add(42); — 42 (int) is autoboxed to Integer silently.',
   'Autoboxing is like an automatic shrink-wrap machine — it wraps your raw item (primitive) in packaging (object) or unwraps it, without you doing it manually.',
   'Unboxing a null Integer causes a NullPointerException, and heavy autoboxing in tight loops creates significant garbage-collection pressure.',
   ARRAY['boxing','unboxing','wrapper','Integer','Double'], 'intermediate', 'framework-specific', 'seed', 'seed'),

  ('con_java_gen',
   'Generics',
   'java programming',
   'A feature allowing classes and methods to operate on typed parameters, enabling type-safe reusable code without casting.',
   'List<String> names = new ArrayList<>(); — only Strings can be added; no cast needed when retrieving.',
   'Generics are like labelled envelopes — you declare up front what type of letter goes inside, so no one accidentally puts the wrong thing in.',
   'Using raw types (List instead of List<String>) losing type safety, or misunderstanding that generics are erased at runtime (type erasure).',
   ARRAY['type-parameter','type-safety','erasure','wildcard'], 'advanced', 'framework-specific', 'seed', 'seed'),

  ('con_java_coll',
   'Collections Framework',
   'java programming',
   'Java''s built-in library of data structures (List, Set, Map, Queue) with common algorithms, in java.util.',
   'Map<String, Integer> freq = new HashMap<>(); freq.put("hello", 1); freq.getOrDefault("world", 0);',
   'The Collections Framework is like a well-stocked kitchen — ArrayList is a pantry shelf (ordered, indexed), HashSet is a spice rack (unique, fast lookup), HashMap is a labelled container per ingredient.',
   'Using ArrayList when frequent middle insertions need LinkedList, or HashMap when insertion order matters (use LinkedHashMap).',
   ARRAY['List','Set','Map','ArrayList','HashMap','Queue'], 'intermediate', 'framework-specific', 'seed', 'seed'),

  ('con_java_exc',
   'Java Exception Hierarchy',
   'java programming',
   'Java''s tree of exception types: Throwable → Error | Exception → RuntimeException | checked exceptions.',
   'IOException is checked (must be caught or declared); NullPointerException is unchecked (RuntimeException); OutOfMemoryError is an Error.',
   'The exception hierarchy is like an emergency response system — minor incidents (checked exceptions) must be planned for; unexpected disasters (unchecked) can strike anywhere.',
   'Catching Exception or Throwable instead of specific types, or throwing checked exceptions from methods where they are never realistically thrown.',
   ARRAY['checked','unchecked','RuntimeException','Error','try-catch'], 'intermediate', 'framework-specific', 'seed', 'seed'),

  ('con_java_lambda',
   'Lambda Expression',
   'java programming',
   'An anonymous function defined inline using the syntax (params) -> body, implementing a functional interface.',
   'list.sort((a, b) -> a.length() - b.length()); sorts strings by length without a named Comparator class.',
   'A lambda is like a quick sticky-note instruction — instead of writing a whole letter (named class), you jot a one-liner and hand it over.',
   'Using lambdas so concisely that the intent is obscure; mutating variables from the enclosing scope (must be effectively final).',
   ARRAY['functional-interface','arrow','stream','Comparator'], 'advanced', 'framework-specific', 'seed', 'seed'),

  ('con_java_stream',
   'Stream API',
   'java programming',
   'A java.util.stream API for processing sequences of elements with declarative pipeline operations (filter, map, reduce, collect).',
   'List<String> upper = names.stream().filter(s -> !s.isEmpty()).map(String::toUpperCase).collect(Collectors.toList());',
   'A Stream is like an assembly line — raw materials flow through stations (filter, map, reduce) and the finished product is collected at the end.',
   'Reusing a stream after it has been consumed (throws IllegalStateException), or using parallel streams without understanding thread-safety implications.',
   ARRAY['filter','map','reduce','collect','pipeline','functional'], 'advanced', 'framework-specific', 'seed', 'seed'),

  ('con_java_thread',
   'Multithreading',
   'java programming',
   'Running multiple threads concurrently within a single JVM process, each with its own call stack but sharing heap memory.',
   'new Thread(() -> System.out.println("Hello from thread")).start(); runs in parallel with the main thread.',
   'Multithreading is like a restaurant kitchen with multiple chefs — they work simultaneously and share ingredients (heap), but must coordinate to avoid chaos.',
   'Race conditions from unsynchronised shared state, deadlocks from incorrect lock ordering, and assuming thread execution order is deterministic.',
   ARRAY['concurrent','thread','synchronised','race-condition','deadlock'], 'advanced', 'framework-specific', 'seed', 'seed'),

  ('con_java_anno',
   'Annotations',
   'java programming',
   'Metadata markers added to code elements (@Override, @Deprecated, custom) that tools, frameworks, and the compiler can read and act on.',
   '@Override signals to the compiler to verify you are overriding a superclass method; Spring''s @Autowired triggers dependency injection.',
   'An annotation is like a sticky label on a file — it does not change the file''s contents but tells the filing system (compiler/framework) how to handle it.',
   'Thinking annotations do something by themselves — they are only useful if something (compiler, reflection, framework) reads and acts on them.',
   ARRAY['metadata','@Override','@Deprecated','reflection','Spring'], 'intermediate', 'framework-specific', 'seed', 'seed'),

  ('con_java_access',
   'Access Modifiers',
   'java programming',
   'Keywords (public, protected, package-private, private) that control the visibility of classes, fields, and methods.',
   'private int balance; means only code inside the same class can read or change balance.',
   'Access modifiers are like building security clearances — some rooms are open to everyone (public), some only to staff on the same floor (package), some only to executives (protected/private).',
   'Defaulting everything to public for convenience, violating encapsulation; or making fields protected thinking it is safer when it is still accessible to all subclasses.',
   ARRAY['private','public','protected','package','visibility'], 'foundation', 'framework-specific', 'seed', 'seed'),

  ('con_java_gc',
   'Garbage Collection',
   'java programming',
   'The automatic JVM process that identifies and frees heap memory occupied by objects no longer reachable from any live reference.',
   'After customerList = null; the Customer objects previously in the list become eligible for GC if no other reference points to them.',
   'Garbage collection is like an automated cleaning crew — you leave things you no longer need and the crew removes them on its own schedule.',
   'Holding unintended references (memory leaks in Java), calling System.gc() expecting immediate collection, or over-allocating in tight loops causing GC pauses.',
   ARRAY['heap','reachability','GC-pause','memory-leak','JVM'], 'intermediate', 'framework-specific', 'seed', 'seed')

ON CONFLICT (canonical_name, domain) DO NOTHING;

-- ── 4. Concept parent links ───────────────────────────────────────────────────
-- Wire domain-specific concepts to their universal parents.
-- Only sets parent_concept_id if the concept has no parent yet.

-- logic → mathematics
UPDATE concepts SET parent_concept_id = (SELECT id FROM concepts WHERE canonical_name = 'Boolean algebra'    AND domain = 'mathematics')
WHERE canonical_name = 'Boolean Expression' AND domain = 'logic' AND parent_concept_id IS NULL;

-- computer science → mathematics
UPDATE concepts SET parent_concept_id = (SELECT id FROM concepts WHERE canonical_name = 'Algorithm'          AND domain = 'mathematics')
WHERE canonical_name = 'Algorithm'          AND domain = 'computer science' AND parent_concept_id IS NULL;

-- programming → mathematics
UPDATE concepts SET parent_concept_id = (SELECT id FROM concepts WHERE canonical_name = 'Variable'           AND domain = 'mathematics')
WHERE canonical_name = 'Variable'           AND domain = 'programming' AND parent_concept_id IS NULL;

UPDATE concepts SET parent_concept_id = (SELECT id FROM concepts WHERE canonical_name = 'Function'           AND domain = 'mathematics')
WHERE canonical_name = 'Function'           AND domain = 'programming' AND parent_concept_id IS NULL;

-- programming → computer science
UPDATE concepts SET parent_concept_id = (SELECT id FROM concepts WHERE canonical_name = 'Recursion'          AND domain = 'computer science')
WHERE canonical_name = 'Recursion'          AND domain = 'programming' AND parent_concept_id IS NULL;

UPDATE concepts SET parent_concept_id = (SELECT id FROM concepts WHERE canonical_name = 'Data Structure'     AND domain = 'computer science')
WHERE canonical_name = 'Array'              AND domain = 'programming' AND parent_concept_id IS NULL;

-- OOP → programming
UPDATE concepts SET parent_concept_id = (SELECT id FROM concepts WHERE canonical_name = 'Function'           AND domain = 'programming')
WHERE canonical_name = 'Constructor'        AND domain = 'object-oriented programming' AND parent_concept_id IS NULL;

UPDATE concepts SET parent_concept_id = (SELECT id FROM concepts WHERE canonical_name = 'Polymorphism'       AND domain = 'object-oriented programming')
WHERE canonical_name = 'Method Overriding'  AND domain = 'object-oriented programming' AND parent_concept_id IS NULL;

-- Java → programming
UPDATE concepts SET parent_concept_id = (SELECT id FROM concepts WHERE canonical_name = 'Function'           AND domain = 'programming')
WHERE canonical_name = 'Main Method'        AND domain = 'java programming' AND parent_concept_id IS NULL;

UPDATE concepts SET parent_concept_id = (SELECT id FROM concepts WHERE canonical_name = 'Data Type'          AND domain = 'programming')
WHERE canonical_name = 'Primitive Types'    AND domain = 'java programming' AND parent_concept_id IS NULL;

UPDATE concepts SET parent_concept_id = (SELECT id FROM concepts WHERE canonical_name = 'Data Type'          AND domain = 'programming')
WHERE canonical_name = 'Autoboxing'         AND domain = 'java programming' AND parent_concept_id IS NULL;

UPDATE concepts SET parent_concept_id = (SELECT id FROM concepts WHERE canonical_name = 'Function'           AND domain = 'programming')
WHERE canonical_name = 'Lambda Expression'  AND domain = 'java programming' AND parent_concept_id IS NULL;

UPDATE concepts SET parent_concept_id = (SELECT id FROM concepts WHERE canonical_name = 'Exception Handling' AND domain = 'programming')
WHERE canonical_name = 'Java Exception Hierarchy' AND domain = 'java programming' AND parent_concept_id IS NULL;

-- Java → OOP
UPDATE concepts SET parent_concept_id = (SELECT id FROM concepts WHERE canonical_name = 'Encapsulation'      AND domain = 'object-oriented programming')
WHERE canonical_name = 'Access Modifiers'   AND domain = 'java programming' AND parent_concept_id IS NULL;

UPDATE concepts SET parent_concept_id = (SELECT id FROM concepts WHERE canonical_name = 'Interface'          AND domain = 'object-oriented programming')
WHERE canonical_name = 'Annotations'        AND domain = 'java programming' AND parent_concept_id IS NULL;

-- Java → computer science
UPDATE concepts SET parent_concept_id = (SELECT id FROM concepts WHERE canonical_name = 'Memory Management'  AND domain = 'computer science')
WHERE canonical_name = 'Garbage Collection' AND domain = 'java programming' AND parent_concept_id IS NULL;

UPDATE concepts SET parent_concept_id = (SELECT id FROM concepts WHERE canonical_name = 'Data Structure'     AND domain = 'computer science')
WHERE canonical_name = 'Collections Framework' AND domain = 'java programming' AND parent_concept_id IS NULL;

UPDATE concepts SET parent_concept_id = (SELECT id FROM concepts WHERE canonical_name = 'Data Structure'     AND domain = 'computer science')
WHERE canonical_name = 'Generics'           AND domain = 'java programming' AND parent_concept_id IS NULL;
