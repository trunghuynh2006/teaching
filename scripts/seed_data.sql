-- =============================================================================
-- seed_data.sql  — Demo content for self-exploration and demo sessions
-- Covers all entities under schemas/content/ and schemas/knowledge/
-- Safe to re-run: all inserts use ON CONFLICT DO NOTHING
-- =============================================================================

-- ---------------------------------------------------------------------------
-- 0. Schema migrations — ensure columns/tables added after initial schema.sql
--    These are idempotent (ADD COLUMN IF NOT EXISTS / CREATE TABLE IF NOT EXISTS)
-- ---------------------------------------------------------------------------

ALTER TABLE folders ADD COLUMN IF NOT EXISTS folder_type VARCHAR(20) NOT NULL DEFAULT 'teacher';
ALTER TABLE folders ADD COLUMN IF NOT EXISTS owner_id    VARCHAR(64);
ALTER TABLE folders ADD COLUMN IF NOT EXISTS program_id  VARCHAR(64);
ALTER TABLE folders ADD COLUMN IF NOT EXISTS is_locked   BOOLEAN NOT NULL DEFAULT FALSE;
ALTER TABLE folders ADD COLUMN IF NOT EXISTS domain      VARCHAR(100);
ALTER TABLE folders ADD COLUMN IF NOT EXISTS theme       VARCHAR(50) NOT NULL DEFAULT '';
ALTER TABLE folders ADD COLUMN IF NOT EXISTS icon        VARCHAR(50) NOT NULL DEFAULT '';

CREATE TABLE IF NOT EXISTS folder_members (
    folder_id  VARCHAR(64) NOT NULL REFERENCES folders(id) ON DELETE CASCADE,
    user_id    VARCHAR(64) NOT NULL,
    role       VARCHAR(20) NOT NULL DEFAULT 'viewer',
    added_by   VARCHAR(64),
    added_time TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    PRIMARY KEY (folder_id, user_id)
);

-- ---------------------------------------------------------------------------
-- 1. Missing tables (entities that exist in schemas but not yet in the DB)
-- ---------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS concepts (
    id           VARCHAR(64) PRIMARY KEY,
    canonical_name VARCHAR(200) NOT NULL,
    domain       VARCHAR(100),
    description  TEXT,
    tags         TEXT[] NOT NULL DEFAULT '{}',
    created_by   VARCHAR(64),
    updated_by   VARCHAR(64),
    created_time TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_time TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS concept_aliases (
    id           VARCHAR(64) PRIMARY KEY,
    concept_id   VARCHAR(64) NOT NULL REFERENCES concepts(id) ON DELETE CASCADE,
    alias        VARCHAR(200) NOT NULL,
    created_by   VARCHAR(64),
    created_time TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS concept_relations (
    concept_a_id  VARCHAR(64) NOT NULL REFERENCES concepts(id) ON DELETE CASCADE,
    concept_b_id  VARCHAR(64) NOT NULL REFERENCES concepts(id) ON DELETE CASCADE,
    relation_type VARCHAR(50) NOT NULL,
    created_by    VARCHAR(64),
    created_time  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    PRIMARY KEY (concept_a_id, concept_b_id, relation_type)
);

CREATE TABLE IF NOT EXISTS topics (
    id           VARCHAR(64) PRIMARY KEY,
    name         VARCHAR(200) NOT NULL,
    folder_id    VARCHAR(64) NOT NULL REFERENCES folders(id) ON DELETE CASCADE,
    description  TEXT NOT NULL DEFAULT '',
    created_by   VARCHAR(64) NOT NULL DEFAULT '',
    updated_by   VARCHAR(64) NOT NULL DEFAULT '',
    created_time TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_time TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_topics_folder_id ON topics (folder_id);

CREATE TABLE IF NOT EXISTS topic_concepts (
    topic_id     VARCHAR(64) NOT NULL REFERENCES topics(id) ON DELETE CASCADE,
    concept_id   VARCHAR(64) NOT NULL REFERENCES concepts(id) ON DELETE CASCADE,
    position     INTEGER NOT NULL DEFAULT 0,
    PRIMARY KEY (topic_id, concept_id)
);

CREATE TABLE IF NOT EXISTS books (
    id           VARCHAR(64) PRIMARY KEY,
    source_id    VARCHAR(64) NOT NULL UNIQUE REFERENCES sources(id) ON DELETE CASCADE,
    author       VARCHAR(200),
    isbn         VARCHAR(50),
    published_at DATE,
    created_by   VARCHAR(64),
    updated_by   VARCHAR(64),
    created_time TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_time TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS chapters (
    id           VARCHAR(64) PRIMARY KEY,
    book_id      VARCHAR(64) NOT NULL REFERENCES books(id) ON DELETE CASCADE,
    title        VARCHAR(200) NOT NULL,
    content      TEXT NOT NULL DEFAULT '',
    position     INTEGER NOT NULL DEFAULT 0,
    created_by   VARCHAR(64),
    updated_by   VARCHAR(64),
    created_time TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_time TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS source_concepts (
    source_id    VARCHAR(64) NOT NULL REFERENCES sources(id) ON DELETE CASCADE,
    concept_id   VARCHAR(64) NOT NULL REFERENCES concepts(id) ON DELETE CASCADE,
    created_by   VARCHAR(64),
    created_time TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    PRIMARY KEY (source_id, concept_id)
);

CREATE TABLE IF NOT EXISTS source_topics (
    source_id    VARCHAR(64) NOT NULL REFERENCES sources(id) ON DELETE CASCADE,
    topic_id     VARCHAR(64) NOT NULL REFERENCES topics(id) ON DELETE CASCADE,
    created_by   VARCHAR(64),
    created_time TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    PRIMARY KEY (source_id, topic_id)
);

-- =============================================================================
-- Microsoft Certified: Power Platform Developer Associate (PL-400)
-- 100 concepts across 10 topics
-- =============================================================================

-- ---------------------------------------------------------------------------
-- Folder
-- ---------------------------------------------------------------------------

INSERT INTO folders (id, folder_type, owner_id, is_locked, name, description, domain, theme, icon, created_by, updated_by)
VALUES
    ('folder_powerplatform01',
     'teacher', 'teacher_john', false,
     'Microsoft Certified: Power Platform Developer Associate',
     'Complete study material for the PL-400 exam covering Dataverse, Power Apps, Power Automate, plugins, PCF, integrations, ALM, and governance.',
     'software', 'purple', 'cloud',
     'teacher_john', 'teacher_john')
ON CONFLICT (id) DO NOTHING;

INSERT INTO folder_members (folder_id, user_id, role, added_by)
VALUES
    ('folder_powerplatform01', 'learner_alex', 'viewer', 'teacher_john'),
    ('folder_powerplatform01', 'learner_mia',  'viewer', 'teacher_john')
ON CONFLICT (folder_id, user_id) DO NOTHING;

-- ---------------------------------------------------------------------------
-- 100 Concepts
-- ---------------------------------------------------------------------------

INSERT INTO concepts (id, canonical_name, domain, description, example,
analogy, common_mistakes, tags, created_by, updated_by)
VALUES

-- ── Group 1: Dataverse Fundamentals ──────────────────────────────────────────
('concept_pp_dataverse01', 'Microsoft Dataverse',
 'software',
 'Cloud-based data storage platform used by Power Platform apps to securely store and manage business data.',
 'A sales app stores Account, Contact, and Opportunity records in Dataverse tables, with row-level access controlled by security roles.',
 'Dataverse is like a managed database service built into Power Platform — similar to SQL Server but with built-in security, API, and auditing.',
 'Treating Dataverse like a plain SQL database and ignoring its abstracted API and security model; confusing it with SharePoint lists.',
 ARRAY['dataverse','power-platform','pl-400'], 'teacher_john', 'teacher_john'),

('concept_pp_table01', 'Dataverse Table',
 'software',
 'A structured container of rows and columns in Dataverse, equivalent to a database table, formerly called an Entity.',
 'The built-in Account table stores company data; a custom Work Order table stores field service requests.',
 'A Dataverse table is like a spreadsheet worksheet — rows are records and columns are fields — but with enforced data types and relationships.',
 'Calling it an "Entity" (the old name) in documentation targeting newer audiences; creating custom tables when standard tables already exist.',
 ARRAY['dataverse','table','schema','pl-400'], 'teacher_john', 'teacher_john'),

('concept_pp_columntype01', 'Column Data Types',
 'software',
 'The set of available column types in Dataverse: Text, Number, Date/Time, Choice, Lookup, Currency, File, and Image.',
 'A Customer Name column uses Text; a Revenue column uses Currency; a Status column uses Choice; a Manager column uses Lookup.',
 'Choosing a column type is like choosing the right container — you would not store water in a paper bag or screws in a liquid bottle.',
 'Using Text for numbers or dates, making filtering and calculations unreliable; confusing Choice (local) with Global Choice.',
 ARRAY['dataverse','column','schema','pl-400'], 'teacher_john', 'teacher_john'),

('concept_pp_onetomany01', 'One-to-Many Relationship',
 'software',
 'A Dataverse table relationship where one row in a parent table relates to multiple rows in a child table via a Lookup column.',
 'One Account can have many Contacts; the Contact table has a Lookup column pointing back to the parent Account.',
 'A one-to-many relationship is like a parent with children — one parent can have many children, but each child has one parent.',
 'Confusing the parent (one) and child (many) sides; forgetting to set cascade behaviors for delete and assign operations.',
 ARRAY['dataverse','relationship','schema','pl-400'], 'teacher_john', 'teacher_john'),

('concept_pp_manytomany01', 'Many-to-Many Relationship',
 'software',
 'A Dataverse relationship where rows in two tables can each be associated with multiple rows in the other, backed by an intersect table.',
 'A Contact can be associated with many Events, and an Event can have many Contacts, backed by a contact_event intersect table.',
 'Like students and courses — one student takes many courses, and one course has many students, tracked via an enrollment record.',
 'Trying to add extra columns to the intersect table when using native N:N relationships; use a custom intersect table when extra data is needed.',
 ARRAY['dataverse','relationship','schema','pl-400'], 'teacher_john', 'teacher_john'),

('concept_pp_solution01', 'Solution',
 'software',
 'A container for Power Platform customizations used to package and transport components (apps, flows, tables) across environments.',
 'A Field Service solution contains the WorkOrder table, a Canvas App, two Cloud Flows, and a security role, all packaged together for deployment.',
 'A solution is like a ZIP file or installer package — it groups all the customizations together so they can be moved as one unit.',
 'Adding components to the Default Solution instead of a proper solution, making them impossible to transport cleanly.',
 ARRAY['alm','solution','power-platform','pl-400'], 'teacher_john', 'teacher_john'),

('concept_pp_publisher01', 'Solution Publisher',
 'software',
 'Defines the customization prefix (e.g. "contoso_") applied to all solution components; identifies the vendor of a solution.',
 'Publisher "Contoso" with prefix "con" means all custom tables and columns get names like con_WorkOrder, con_Priority.',
 'A publisher prefix is like a namespace in code — it prevents naming collisions between solutions from different vendors.',
 'Using the default publisher prefix "new_" in production solutions; changing the prefix after components have already been created.',
 ARRAY['alm','solution','prefix','pl-400'], 'teacher_john', 'teacher_john'),

('concept_pp_managed01', 'Managed vs Unmanaged Solution',
 'software',
 'Managed solutions are locked, distributable packages; unmanaged solutions allow direct customization and are used during development.',
 'Developers work in an unmanaged solution in Dev; the pipeline exports a managed solution and imports it into UAT and Production.',
 'Unmanaged is like source code you can edit; managed is like a compiled binary you can install but not modify directly.',
 'Customizing managed solution components directly in Production; importing an unmanaged solution into Production.',
 ARRAY['alm','solution','deployment','pl-400'], 'teacher_john', 'teacher_john'),

('concept_pp_securityrole01', 'Security Role',
 'software',
 'A set of privileges that define what operations (Create, Read, Update, Delete) a user can perform on Dataverse tables.',
 'A "Sales Representative" security role grants Read/Create/Update on Opportunity at user level and Read on Account at business unit level.',
 'A security role is like a job access badge — it defines which doors (tables and operations) the badge holder can open.',
 'Editing the System Administrator role; not testing roles with the Check Access feature; giving global access when user-level is sufficient.',
 ARRAY['security','dataverse','access-control','pl-400'], 'teacher_john', 'teacher_john'),

('concept_pp_businessunit01', 'Business Unit',
 'software',
 'A hierarchical organizational unit in Dataverse used to group users and control data access scope through security roles.',
 'A global company creates Business Units for each region; a user in the EMEA BU can only see records owned by other EMEA users.',
 'Business Units are like departments in an org chart — they define which team a user belongs to and what data that team can access.',
 'Placing all users in the root BU, losing the ability to scope data access by team or region.',
 ARRAY['security','dataverse','organization','pl-400'], 'teacher_john', 'teacher_john'),

-- ── Group 2: Dataverse Advanced Features ─────────────────────────────────────
('concept_pp_calculated01', 'Calculated Column',
 'software',
 'A Dataverse column whose value is automatically computed from a formula referencing other columns in the same row.',
 'A Full Name column calculated as FirstName + " " + LastName; a Days Open column calculated as TODAY() minus CreatedOn.',
 'Like a formula cell in Excel — you define the formula once and it always shows the computed result based on sibling cells.',
 'Using a Calculated Column for values that need to be searchable or filterable efficiently; they cannot reference related table columns.',
 ARRAY['dataverse','column','formula','pl-400'], 'teacher_john', 'teacher_john'),

('concept_pp_rollup01', 'Rollup Column',
 'software',
 'A Dataverse column that aggregates values (sum, count, min, max, avg) from related child rows on a scheduled basis.',
 'Total Revenue on an Account row rolls up the sum of all closed Opportunity amounts related to that account, recalculated every 12 hours.',
 'Like a subtotal row at the bottom of a spreadsheet that automatically sums the child rows above it.',
 'Expecting real-time updates — rollup columns are asynchronous; using them in plugins where freshness is critical.',
 ARRAY['dataverse','column','aggregation','pl-400'], 'teacher_john', 'teacher_john'),

('concept_pp_altkey01', 'Alternate Key',
 'software',
 'A unique key defined on one or more columns that can identify a Dataverse row without using the primary GUID, used for upsert operations.',
 'An Order table has an alternate key on OrderNumber, enabling upsert calls like PATCH /orders(OrderNumber=''ORD-001'').',
 'An alternate key is like using an employee badge number instead of an internal employee ID to look someone up — unique and meaningful to the caller.',
 'Defining alternate keys on columns with duplicate or null values; not using them in integration upsert calls, causing duplicate record creation.',
 ARRAY['dataverse','schema','upsert','pl-400'], 'teacher_john', 'teacher_john'),

('concept_pp_elastictable01', 'Elastic Table',
 'software',
 'A Dataverse table type built on Azure Cosmos DB, designed for high-volume, high-velocity scenarios with flexible schemas.',
 'IoT sensor readings and telemetry events stored in an elastic table can handle millions of inserts per day with flexible JSON schemas.',
 'An elastic table is like a NoSQL document store plugged into Dataverse — great for high-volume, schema-variable data, unlike relational standard tables.',
 'Using elastic tables for relational data or workflows requiring transactional consistency; they do not support plugins or business rules.',
 ARRAY['dataverse','table','nosql','pl-400'], 'teacher_john', 'teacher_john'),

('concept_pp_auditlog01', 'Audit Log',
 'software',
 'Dataverse feature that records who created, modified, or deleted records and when, for compliance and troubleshooting.',
 'Enabling audit on the Contact table records every field change with the old and new value, who changed it, and when.',
 'An audit log is like CCTV footage for your data — you can replay exactly who changed what and when.',
 'Enabling audit on all tables and columns without considering storage costs; forgetting to configure the audit log retention period.',
 ARRAY['dataverse','audit','governance','pl-400'], 'teacher_john', 'teacher_john'),

('concept_pp_dvsearch01', 'Dataverse Search',
 'software',
 'A full-text, relevance-based search service across multiple Dataverse tables, powered by Azure Cognitive Search.',
 'Searching "Contoso" across Account, Contact, and Opportunity tables returns ranked results based on relevance across all configured tables.',
 'Dataverse Search is like a search engine for your Dataverse data — it finds relevant records across multiple tables, not just one at a time.',
 'Confusing Dataverse Search with Quick Find (single-table keyword search); tables and columns must be explicitly enabled for Dataverse Search.',
 ARRAY['dataverse','search','full-text','pl-400'], 'teacher_john', 'teacher_john'),

('concept_pp_virtualcol01', 'Virtual Column',
 'software',
 'A Dataverse column that retrieves its value from an external data source at query time without storing data in Dataverse.',
 'A virtual Currency column on a Quote table retrieves the live exchange rate from an external finance API each time the record is opened.',
 'A virtual column is like a live link in a spreadsheet that pulls data from an external source each time you view it, never storing a copy locally.',
 'Filtering or sorting on virtual columns — they are computed at read time and do not support server-side query operations.',
 ARRAY['dataverse','column','virtual','pl-400'], 'teacher_john', 'teacher_john'),

('concept_pp_choice01', 'Choice Column',
 'software',
 'A Dataverse column type (formerly Option Set) that stores a value from a predefined list of integer-label pairs.',
 'A Status column with choices: Active (1), Inactive (2), Pending (3). Code references the integer value; the UI displays the label.',
 'A Choice column is like a dropdown menu where each visible option maps to a hidden integer stored in the database.',
 'Hardcoding integer values in code instead of using the generated enum constants; confusing a local Choice with a reusable Global Choice.',
 ARRAY['dataverse','column','option-set','pl-400'], 'teacher_john', 'teacher_john'),

('concept_pp_polylookup01', 'Polymorphic Lookup',
 'software',
 'A Lookup column in Dataverse that can reference rows from more than one table type (e.g. Customer lookup to Account or Contact).',
 'The built-in Regarding column on Activity tables is polymorphic — it can point to an Account, a Contact, a Lead, or a custom table.',
 'A polymorphic lookup is like a universal remote control — one physical remote that can point to a TV, a soundbar, or a streaming box.',
 'Forgetting to filter the lookup view to the expected table types; complex filtering logic is needed in client-side code.',
 ARRAY['dataverse','relationship','lookup','pl-400'], 'teacher_john', 'teacher_john'),

('concept_pp_tableperm01', 'Table Permission',
 'software',
 'A Power Pages security construct that grants website users access to Dataverse table rows based on scope (Global, Contact, Account, etc.).',
 'A "Self" scoped Table Permission on Contact allows a Power Pages user to read and update only their own Contact record.',
 'Table Permissions are like bouncer rules at a website — they determine which Dataverse records external website users are allowed to see or edit.',
 'Granting Global scope Table Permissions unintentionally, exposing all records to all authenticated website users.',
 ARRAY['power-pages','security','dataverse','pl-400'], 'teacher_john', 'teacher_john'),

-- ── Group 3: Power Apps Development ──────────────────────────────────────────
('concept_pp_canvasapp01', 'Canvas App',
 'software',
 'A Power Apps application built on a blank canvas where developers control every UI element, layout, and behavior using Power Fx formulas.',
 'A field technician app with a custom gallery of work orders, a details screen, and a camera control for capturing photos, built on a blank canvas.',
 'Building a Canvas App is like designing a PowerPoint slide deck with live data connections — you control every pixel and interaction.',
 'Not designing for delegation early; nesting too many galleries causing performance issues; storing sensitive data in global variables.',
 ARRAY['power-apps','canvas','pl-400'], 'teacher_john', 'teacher_john'),

('concept_pp_mdapp01', 'Model-Driven App',
 'software',
 'A Power Apps application generated from Dataverse metadata, automatically rendering forms, views, charts, and dashboards.',
 'A CRM app generated from Account, Contact, and Opportunity tables, showing auto-generated forms, views, and dashboards based on metadata.',
 'A Model-Driven App is like a ready-made house interior — Dataverse is the blueprint, and Power Apps renders the furniture (forms, views) automatically.',
 'Trying to control pixel-level layout as with Canvas Apps; MDA layout is controlled by metadata, not a design canvas.',
 ARRAY['power-apps','model-driven','dataverse','pl-400'], 'teacher_john', 'teacher_john'),

('concept_pp_powerfx01', 'Power Fx Formula',
 'software',
 'The low-code formula language used in Canvas Apps, inspired by Excel, for defining logic, data operations, and navigation.',
 'Filter(Accounts, StartsWith(Name, TextInput1.Text)) filters an Accounts gallery as the user types; Patch() saves changes back to Dataverse.',
 'Power Fx is like Excel formulas but for app logic — familiar syntax extended with app actions like navigation, data writes, and variable management.',
 'Writing imperative code patterns (loops, variables) instead of leveraging functional/declarative Power Fx; overusing global variables.',
 ARRAY['power-apps','power-fx','formula','pl-400'], 'teacher_john', 'teacher_john'),

('concept_pp_connector01', 'Connector',
 'software',
 'A proxy wrapper around an external API that Power Apps and Power Automate use to communicate with services like SharePoint, SQL, or custom APIs.',
 'The SharePoint connector connects a Canvas App to a SharePoint list; the SQL Server connector streams records from an Azure SQL database.',
 'A connector is like a universal adapter plug — it translates between Power Apps''s standard interface and the specific API of each external service.',
 'Ignoring connector premium tier costs when selecting Standard vs Premium connectors; each data call counts against API limits.',
 ARRAY['power-apps','connector','integration','pl-400'], 'teacher_john', 'teacher_john'),

('concept_pp_delegation01', 'Delegation',
 'software',
 'The ability for a Canvas App data function to push query processing to the data source rather than downloading all records locally, avoiding the row limit.',
 'Filter(Accounts, Status = "Active") delegates to Dataverse and returns matching records server-side. Search() on a local collection is not delegable.',
 'Delegation is like asking the library to find books on a topic versus downloading the entire catalog and searching it yourself at home.',
 'Using non-delegable functions (Search, CountIf on some sources) on large datasets, triggering the 500/2000-row data row limit silently.',
 ARRAY['power-apps','performance','data','pl-400'], 'teacher_john', 'teacher_john'),

('concept_pp_collection01', 'Collection',
 'software',
 'An in-memory table stored locally in a Canvas App, created with Collect() or ClearCollect(), used for caching or staging data.',
 'ClearCollect(MyOrders, Filter(Orders, Owner = User().Email)) caches the user''s orders in a local collection for fast screen navigation.',
 'A Collection is like a shopping cart — a temporary local store that holds data for the session, not permanently saved anywhere.',
 'Treating collections as persistent storage — they are cleared when the app closes; using Collect() instead of ClearCollect() and accumulating duplicates.',
 ARRAY['power-apps','canvas','data','pl-400'], 'teacher_john', 'teacher_john'),

('concept_pp_gallery01', 'Gallery Control',
 'software',
 'A Canvas App control that displays a scrollable list of records where each item shares the same layout template.',
 'A Gallery bound to a Customers table displays each customer''s name, photo, and last contact date using a template that repeats per row.',
 'A Gallery is like a physical bulletin board with repeating card slots — you design one card template and the board fills in the data automatically.',
 'Using ThisItem inside nested galleries without careful scoping; performance issues from galleries loading thousands of rows without filtering.',
 ARRAY['power-apps','canvas','ui','pl-400'], 'teacher_john', 'teacher_john'),

('concept_pp_appform01', 'App Form Control',
 'software',
 'A Canvas or Model-Driven App control for displaying and editing a single Dataverse row, supporting Edit, View, and New modes.',
 'An EditForm bound to the Projects table in Edit mode auto-generates input fields; SubmitForm() writes the changed data back to Dataverse.',
 'An App Form Control is like a pre-printed paper form — the fields are laid out automatically and mapped to the right data fields in the database.',
 'Calling Patch() to save data when a Form control is present — use SubmitForm(); forgetting to call ResetForm() after a successful submit.',
 ARRAY['power-apps','form','dataverse','pl-400'], 'teacher_john', 'teacher_john'),

('concept_pp_custompage01', 'Custom Page',
 'software',
 'A Canvas App page embedded inside a Model-Driven App, enabling rich custom UI while retaining access to Dataverse context.',
 'A richly formatted order summary page built in Canvas App style is embedded as a Custom Page inside a Model-Driven App for a seamless UX.',
 'A Custom Page is like inserting a hand-crafted brochure page into a standardized report binder — custom look within a structured container.',
 'Overusing Custom Pages for simple forms that standard MDA forms handle well; Custom Pages require careful navigation and context passing.',
 ARRAY['power-apps','model-driven','canvas','pl-400'], 'teacher_john', 'teacher_john'),

('concept_pp_appdesigner01', 'App Designer',
 'software',
 'The visual tool in the Power Apps maker portal for configuring a Model-Driven App''s navigation, forms, views, and dashboards.',
 'In App Designer, a developer adds the Account and Contact tables, selects which views and forms to expose, and sets up the sitemap navigation.',
 'App Designer is like a table of contents editor — it decides which chapters (tables, views, forms) are included and how users navigate between them.',
 'Editing the sitemap directly in XML instead of using App Designer; including too many tables, making the app navigation confusing.',
 ARRAY['power-apps','model-driven','tooling','pl-400'], 'teacher_john', 'teacher_john'),

-- ── Group 4: PCF and Client Scripting ────────────────────────────────────────
('concept_pp_pcf01', 'Power Apps Component Framework (PCF)',
 'software',
 'A framework for building reusable code components using TypeScript and standard web technologies that run inside Canvas or Model-Driven Apps.',
 'A custom PCF control renders a colour-coded urgency badge instead of a plain text field on a Model-Driven App form.',
 'PCF is like a browser extension for Power Apps UI — it lets you replace default field renderings with fully custom HTML/CSS/JS controls.',
 'Trying to use PCF to perform data writes outside the control''s bound field; PCF controls are UI-only unless using the Web API from within.',
 ARRAY['pcf','power-apps','typescript','pl-400'], 'teacher_john', 'teacher_john'),

('concept_pp_typescript01', 'TypeScript in PCF',
 'software',
 'PCF components are authored in TypeScript; the framework provides a strongly-typed manifest and lifecycle interface (init, updateView, destroy).',
 'The PCF init() method receives the context with the bound field value; updateView() re-renders when the value or app state changes.',
 'The PCF lifecycle (init, updateView, destroy) is like a React component lifecycle (componentDidMount, componentDidUpdate, componentWillUnmount).',
 'Not calling notifyOutputChanged() after user interaction, so the bound field value never updates; missing destroy() cleanup causing memory leaks.',
 ARRAY['pcf','typescript','development','pl-400'], 'teacher_john', 'teacher_john'),

('concept_pp_reactpcf01', 'React Virtual PCF Control',
 'software',
 'A PCF control type that renders through a shared React root managed by Power Apps, improving performance by avoiding per-control React instances.',
 'A Virtual PCF control renders a React date-picker component inside the shared Power Apps React root, avoiding duplicate React instances.',
 'A Virtual PCF control is like a sub-component inside a parent React app — it shares the React root rather than spinning up its own isolated tree.',
 'Using Standard (non-virtual) PCF when React is needed, causing multiple conflicting React instances per page.',
 ARRAY['pcf','react','virtual','pl-400'], 'teacher_john', 'teacher_john'),

('concept_pp_pcfmanifest01', 'PCF Manifest',
 'software',
 'The ControlManifest.Input.xml file that declares a PCF component''s properties, resources, and feature usage to the Power Apps runtime.',
 'The manifest declares a property "primaryColor" of type SingleLine.Text, which the app maker binds to a Dataverse column or provides a static value.',
 'The PCF manifest is like the spec sheet for a component — it tells Power Apps what inputs the component accepts and what resources it needs.',
 'Forgetting to update the version in the manifest before publishing updated components; property type mismatches causing runtime binding errors.',
 ARRAY['pcf','manifest','configuration','pl-400'], 'teacher_john', 'teacher_john'),

('concept_pp_xrm01', 'Client API (Xrm)',
 'software',
 'The JavaScript object model (window.Xrm) available in Model-Driven Apps for manipulating forms, fields, tabs, and navigating records.',
 'formContext.getAttribute("priority").setValue(3) sets the Priority field value; formContext.ui.tabs.get("tab1").setVisible(false) hides a tab.',
 'The Xrm Client API is like the DOM for Model-Driven App forms — it gives JavaScript programmatic access to every form element.',
 'Using document.getElementById() to manipulate form elements instead of the Xrm API — direct DOM access is unsupported and breaks in updates.',
 ARRAY['client-api','xrm','javascript','pl-400'], 'teacher_john', 'teacher_john'),

('concept_pp_formevent01', 'Form Event',
 'software',
 'Events fired during the Model-Driven App form lifecycle: OnLoad, OnSave, and OnChange, to which JavaScript handlers can be registered.',
 'An OnLoad handler pre-fills a default Territory field; an OnSave handler validates that a required document is attached before allowing save.',
 'Form events are like hooks in a web framework — they fire at lifecycle points and let you inject custom logic without modifying the platform code.',
 'Performing synchronous HTTP calls inside OnSave without returning a promise, causing the event to complete before the call finishes.',
 ARRAY['client-api','form','events','pl-400'], 'teacher_john', 'teacher_john'),

('concept_pp_fieldevent01', 'Field (Column) Event',
 'software',
 'OnChange event on a Model-Driven App form field that fires when a user changes the field value, used for field-level business logic.',
 'An OnChange handler on the Country field filters the Region lookup to show only regions for the selected country.',
 'A field event is like an onChange listener on an HTML input — it fires whenever the user changes the value, allowing reactive field updates.',
 'Triggering infinite loops by programmatically setting a field value inside its own OnChange handler; use fireOnChange: false when setting values in code.',
 ARRAY['client-api','field','events','pl-400'], 'teacher_john', 'teacher_john'),

('concept_pp_jswebres01', 'JavaScript Web Resource',
 'software',
 'A .js file stored in Dataverse as a web resource and referenced by form event handlers or ribbon commands in Model-Driven Apps.',
 'A file myapp_formlogic.js registered as a web resource is attached to the Contact form OnLoad event to run business logic on form load.',
 'A JavaScript Web Resource is like a script tag included in a webpage — the file is stored in Dataverse and loaded when the form opens.',
 'Not using a namespace for functions (risk of name collision with other web resources); caching issues after updates requiring a version increment.',
 ARRAY['web-resource','javascript','model-driven','pl-400'], 'teacher_john', 'teacher_john'),

('concept_pp_htmlwebres01', 'HTML Web Resource',
 'software',
 'A .html file stored as a Dataverse web resource, embeddable as an iframe inside a Model-Driven App form for fully custom UI.',
 'An HTML web resource displays a custom status timeline iframe inside a form, pulling data from an external service via JavaScript.',
 'An HTML Web Resource embedded in a form is like an iframe pointing to a mini-website hosted inside Dataverse rather than an external server.',
 'Trying to access the parent form''s formContext from inside an HTML web resource iframe — only allowed via the getContentWindow API.',
 ARRAY['web-resource','html','model-driven','pl-400'], 'teacher_john', 'teacher_john'),

('concept_pp_commandbar01', 'Command Bar Customization',
 'software',
 'Customizing the ribbon/command bar buttons in Model-Driven Apps using the modern Command Designer or classic Ribbon Workbench.',
 'Adding a custom "Generate PDF" button to the Account form command bar using Command Designer, with a JavaScript action and an enable rule.',
 'Command bar customization is like configuring toolbar buttons in Word — you choose which actions appear and when they are enabled or visible.',
 'Using the legacy Ribbon Workbench when Command Designer supports the use case; forgetting visibility and enable rules causes confusing UX.',
 ARRAY['model-driven','ribbon','command','pl-400'], 'teacher_john', 'teacher_john'),

-- ── Group 5: Power Automate Fundamentals ─────────────────────────────────────
('concept_pp_cloudflow01', 'Cloud Flow',
 'software',
 'A Power Automate automation that runs in the cloud, connecting services via triggers and actions without requiring local infrastructure.',
 'A Cloud Flow triggers when a new Dataverse row is created for a Lead, sends a welcome email, and creates a follow-up Task record.',
 'A Cloud Flow is like an automated assembly line — events arrive at one end and are processed through a defined sequence of steps automatically.',
 'Hardcoding environment-specific URLs or IDs inside flow actions instead of using Environment Variables.',
 ARRAY['power-automate','flow','automation','pl-400'], 'teacher_john', 'teacher_john'),

('concept_pp_flowtrigger01', 'Flow Trigger',
 'software',
 'The event that starts a Cloud Flow, such as when a Dataverse row is created, a schedule fires, or an HTTP request is received.',
 'A "When a row is added, modified or deleted" Dataverse trigger fires every time a new Opportunity is created with Status = Open.',
 'A trigger is like a motion sensor on a door — it detects that something happened and wakes up the flow to respond.',
 'Using polling triggers (every minute) when event-driven triggers are available, wasting API quota and increasing latency.',
 ARRAY['power-automate','trigger','event','pl-400'], 'teacher_john', 'teacher_john'),

('concept_pp_flowaction01', 'Flow Action',
 'software',
 'A unit of work in a Cloud Flow that performs an operation, such as sending an email, updating a Dataverse row, or calling an HTTP endpoint.',
 'A "Send an email (V2)" action sends a notification; a "Get a row by ID" action fetches Dataverse data for use in later steps.',
 'A flow action is like a single step in a recipe — each step does one thing (mix, bake, cool), and steps are chained to complete the dish.',
 'Not configuring retry policies on actions that call external APIs, leading to transient failures causing the entire flow to fail.',
 ARRAY['power-automate','action','step','pl-400'], 'teacher_john', 'teacher_john'),

('concept_pp_condition01', 'Condition',
 'software',
 'A Power Automate control action that branches flow execution into "If yes" and "If no" paths based on a boolean expression.',
 'A Condition checks if Priority equals "High"; the "If yes" branch sends a Slack alert; the "If no" branch logs to a SharePoint list.',
 'A Condition is like a road fork with a signpost — depending on which way the condition points, the flow takes the left or right branch.',
 'Nesting many Conditions deeply instead of using a Switch action for multiple discrete values.',
 ARRAY['power-automate','logic','branching','pl-400'], 'teacher_john', 'teacher_john'),

('concept_pp_applytoeach01', 'Apply to Each',
 'software',
 'A Power Automate loop control that iterates over each item in an array, executing nested actions for every element.',
 'Apply to Each iterates over a list of new employee emails returned from a query, sending an onboarding email to each one.',
 'Apply to Each is like a for-each loop — for every item in a list, execute the same set of steps with that item as context.',
 'Using Apply to Each when a bulk action is available; nested Apply to Each blocks can cause performance problems.',
 ARRAY['power-automate','loop','array','pl-400'], 'teacher_john', 'teacher_john'),

('concept_pp_errorhandling01', 'Flow Error Handling',
 'software',
 'Using Scope actions with "Configure run after" settings (failed, skipped, timed out) to implement try/catch patterns in Cloud Flows.',
 'A Scope action wraps critical steps; a parallel branch with "Configure run after" set to "has failed" sends a Teams alert and logs the error.',
 'Scope with error handling is like a try/catch block in code — the Scope is the try, and the parallel failed-branch is the catch.',
 'Not configuring "Configure run after" on the catch branch, so it only runs on success by default; forgetting to surface the error message for debugging.',
 ARRAY['power-automate','error-handling','resilience','pl-400'], 'teacher_john', 'teacher_john'),

('concept_pp_envvar01', 'Environment Variable',
 'software',
 'A solution component that stores configuration values (strings, numbers, JSON, secrets) separately from flow logic, enabling environment-specific settings.',
 'A SharePoint Site URL Environment Variable is set to the DEV site in Development and the PROD site in Production, with no flow edits needed.',
 'An Environment Variable in Power Platform is like a .env file entry — it externalizes configuration so the same logic runs with different settings per environment.',
 'Hardcoding environment-specific values inside flow actions instead of referencing Environment Variables; missing variable values block solution import.',
 ARRAY['power-automate','alm','configuration','pl-400'], 'teacher_john', 'teacher_john'),

('concept_pp_connref01', 'Connection Reference',
 'software',
 'A solution component that abstracts the connection used by a connector, allowing credentials to be swapped per environment without editing the flow.',
 'A Connection Reference named "Shared SharePoint Connection" points to different credentials in each environment, set during solution import.',
 'A Connection Reference is like a named database connection string in a config file — the logic refers to the name, and the actual credentials are swapped per environment.',
 'Creating flows without Connection References in a solution, making it impossible to change credentials without editing the flow directly.',
 ARRAY['power-automate','alm','connector','pl-400'], 'teacher_john', 'teacher_john'),

('concept_pp_approval01', 'Approval Flow',
 'software',
 'A Power Automate pattern using the Approvals connector to route items for human review, collecting approve/reject responses before continuing.',
 'A flow sends an Approval request to a manager when an expense report exceeds $1000; the flow resumes once the manager approves or rejects in Teams.',
 'An Approval Flow is like a digital signature workflow — work pauses, a human is notified, and the flow resumes only after a person acts.',
 'Not handling the "Reject" outcome and allowing the flow to continue as if approved; approvals time out after 30 days by default.',
 ARRAY['power-automate','approval','human-in-loop','pl-400'], 'teacher_john', 'teacher_john'),

('concept_pp_childflow01', 'Child Flow',
 'software',
 'A Cloud Flow called from another flow using the "Run a Child Flow" action, enabling reusable flow logic shared across multiple parent flows.',
 'A "Send Notification" child flow is reused by an onboarding flow, an offboarding flow, and a contract renewal flow, all calling it with different messages.',
 'A child flow is like a function in programming — you write it once with parameters and call it from multiple parent flows instead of duplicating logic.',
 'Creating child flows in the Default Solution, which makes them inaccessible to flows in managed solutions in other environments.',
 ARRAY['power-automate','reuse','modular','pl-400'], 'teacher_john', 'teacher_john'),

-- ── Group 6: Business Process Automation ─────────────────────────────────────
('concept_pp_bpf01', 'Business Process Flow',
 'software',
 'A guided, stage-based process overlay in Model-Driven Apps that walks users through required steps to complete a business process.',
 'A "Sales Pipeline" BPF has stages: Qualify → Develop → Propose → Close, each with mandatory fields before the user can advance.',
 'A BPF is like a guided wizard in an application — it walks the user through required steps in order, preventing skipping ahead.',
 'Confusing a BPF stage with a workflow step; BPFs guide human interaction, not automated server-side logic.',
 ARRAY['power-automate','bpf','process','pl-400'], 'teacher_john', 'teacher_john'),

('concept_pp_bpfstage01', 'BPF Stage',
 'software',
 'A named phase in a Business Process Flow containing data steps (fields) the user must complete before advancing to the next stage.',
 'The "Develop" stage in a sales BPF requires the user to fill in Budget Amount and Decision Maker before the Next Stage button becomes active.',
 'A BPF Stage is like a level in a video game — you must complete the objectives of the current level to unlock the next.',
 'Adding too many required fields per stage, frustrating users; not testing the BPF behavior when stages are skipped or the record is branched.',
 ARRAY['bpf','stage','process','pl-400'], 'teacher_john', 'teacher_john'),

('concept_pp_bizrule01', 'Business Rule',
 'software',
 'A no-code rule configured on a Dataverse table that enforces field requirements, visibility, or default values on forms and server-side.',
 'A business rule makes the Discount field required when Deal Size is "Enterprise" and sets a default 5% value when Deal Size is "SMB".',
 'A Business Rule is like a conditional formatting rule in Excel applied to a form — it shows, hides, or requires fields based on other field values.',
 'Using Business Rules for complex logic that changes data in related tables — they only operate on the current table row and form.',
 ARRAY['dataverse','business-rule','no-code','pl-400'], 'teacher_john', 'teacher_john'),

('concept_pp_custaction01', 'Custom Process Action',
 'software',
 'A reusable, named Dataverse operation that can be called from flows, plugins, or client scripts, similar to a lightweight custom API.',
 'A "CalculateDiscount" Custom Process Action takes a Deal ID as input, runs pricing logic, and returns a Discount Percentage as output.',
 'A Custom Process Action is like a named stored procedure — it encapsulates reusable logic callable from flows, plugins, or client scripts by name.',
 'Overusing Custom Process Actions when a simpler Instant Flow or plugin would be more maintainable; they are harder to debug than flows.',
 ARRAY['dataverse','process','reuse','pl-400'], 'teacher_john', 'teacher_john'),

('concept_pp_customapi01', 'Custom API',
 'software',
 'A Dataverse extension point that exposes a custom message callable via the Web API, backed by a plugin, with defined request/response parameters.',
 'A "GenerateInvoice" Custom API exposes a message backed by a plugin, callable via POST /api/data/v9.2/GenerateInvoice with JSON parameters.',
 'A Custom API is like defining a new verb for Dataverse — instead of only Create/Update/Delete, you add your own named operation with typed parameters.',
 'Not registering the backing plugin step for the Custom API message; leaving the Custom API without a plugin makes it a no-op that returns nothing.',
 ARRAY['dataverse','api','plugin','pl-400'], 'teacher_john', 'teacher_john'),

('concept_pp_scheduledflow01', 'Scheduled Flow',
 'software',
 'A Cloud Flow triggered on a recurring schedule (every X minutes/hours/days), used for batch processing or periodic data synchronization.',
 'A Scheduled Flow runs every day at 2 AM, queries Dataverse for overdue tasks, and sends a daily digest email to each task owner.',
 'A Scheduled Flow is like a cron job — a clock fires it on a fixed schedule rather than waiting for an external event.',
 'Not handling large datasets efficiently in scheduled flows; polling all records without date filters causes unnecessary API usage and timeouts.',
 ARRAY['power-automate','schedule','batch','pl-400'], 'teacher_john', 'teacher_john'),

('concept_pp_automatedflow01', 'Automated Flow',
 'software',
 'A Cloud Flow triggered automatically by an event in a connected service, such as a new Dataverse row or an incoming email.',
 'An Automated Flow triggers on "When a new email arrives in a shared mailbox" and creates a Dataverse Case record from the email details.',
 'An Automated Flow is like a reactive event listener — it sits silently and springs into action the moment the watched event occurs.',
 'Triggers firing more than expected due to broad trigger conditions; always add filter conditions to narrow when the flow actually executes.',
 ARRAY['power-automate','automated','event','pl-400'], 'teacher_john', 'teacher_john'),

('concept_pp_instantflow01', 'Instant Flow',
 'software',
 'A Cloud Flow triggered manually by a user from the Power Automate app, a Power Apps button, or a Teams message action.',
 'An Instant Flow is triggered by a button in a Canvas App, receives the selected record ID as input, and runs a PDF generation process.',
 'An Instant Flow is like a vending machine button — the user pushes it on demand and the automation runs immediately on request.',
 'Building Instant Flows that depend on context (the selected record) without passing the record ID as an input parameter.',
 ARRAY['power-automate','manual','button','pl-400'], 'teacher_john', 'teacher_john'),

('concept_pp_desktopflow01', 'Desktop Flow (RPA)',
 'software',
 'A Power Automate automation that runs on a local machine to automate legacy or desktop applications through UI interaction (Robotic Process Automation).',
 'A Desktop Flow opens a legacy ERP application, reads order data from a screen, and pastes it into a web form — all through UI automation.',
 'A Desktop Flow is like a robot sitting at a computer — it moves the mouse, clicks buttons, and types data just as a human would.',
 'Using Desktop Flows for systems with available APIs — RPA is the last resort when no API exists, as it is fragile to UI changes.',
 ARRAY['power-automate','rpa','desktop','pl-400'], 'teacher_john', 'teacher_john'),

('concept_pp_classicwf01', 'Classic Workflow',
 'software',
 'A legacy Dataverse automation (background/real-time process) that predates Power Automate; still supported but recommended to migrate to Cloud Flows.',
 'A classic background workflow runs after an Opportunity is won, automatically creating a follow-up Task and updating the related Account stage.',
 'A Classic Workflow is like a veteran office worker who still uses paper forms — it gets the job done but the modern equivalent (Cloud Flow) is faster and more capable.',
 'Creating new Classic Workflows when Power Automate Cloud Flows cover the same scenario; Workflows lack modern monitoring and cannot be imported into GitHub easily.',
 ARRAY['dataverse','workflow','legacy','pl-400'], 'teacher_john', 'teacher_john'),

-- ── Group 7: Plugin Development ───────────────────────────────────────────────
('concept_pp_plugin01', 'Plugin',
 'software',
 'A .NET assembly containing event-handler classes that execute synchronously or asynchronously in response to Dataverse data operations.',
 'A plugin registered on the Create message of the Order table calculates the total price and sets the TotalAmount field before the record is saved.',
 'A plugin is like a database trigger but for Dataverse — it intercepts a data operation and runs custom .NET code before or after it completes.',
 'Writing plugins that call external HTTP services synchronously in Pre-Operation, blocking the user save transaction and causing timeouts.',
 ARRAY['plugin','dataverse','dotnet','pl-400'], 'teacher_john', 'teacher_john'),

('concept_pp_pluginstep01', 'Plugin Step',
 'software',
 'The registration of a plugin class against a specific Dataverse message (e.g. Create, Update) and table at a chosen pipeline stage (Pre/Post-Operation).',
 'A Pre-Operation step on Update of the Contact table for attribute filter "Email" runs validation logic only when the Email field changes.',
 'A plugin step registration is like setting up an event listener — you specify exactly which event, table, stage, and attributes trigger the handler.',
 'Not using attribute filtering, causing the plugin to run on every Update regardless of which fields changed, wasting resources.',
 ARRAY['plugin','registration','step','pl-400'], 'teacher_john', 'teacher_john'),

('concept_pp_pluginimage01', 'Plugin Image',
 'software',
 'A snapshot of a Dataverse row''s column values captured before (Pre-Image) or after (Post-Image) an operation, available to the plugin for comparison.',
 'A Pre-Image on an Update step captures the old Email value before the update; the plugin compares it to the new value to detect changes.',
 'A plugin image is like a before-and-after photo — the Pre-Image is the "before" snapshot and the Post-Image is the "after" snapshot of the record.',
 'Expecting Pre-Images on Create steps (they do not exist since there is no previous state); Post-Images on Delete steps are also not available.',
 ARRAY['plugin','image','snapshot','pl-400'], 'teacher_john', 'teacher_john'),

('concept_pp_iorgservice01', 'IOrganizationService',
 'software',
 'The primary Dataverse service interface in a plugin, used to execute CRUD operations, queries, and custom messages against Dataverse.',
 'service.Create(new Entity("task") { ["subject"] = "Follow up", ["regardingobjectid"] = accountRef }) creates a Task linked to an Account.',
 'IOrganizationService is like the Dataverse SDK client — it is the main handle for all CRUD and message operations inside a plugin or custom code.',
 'Creating a new IOrganizationService inside the plugin instead of obtaining it from IServiceProvider — always use the provided factory to get the service.',
 ARRAY['plugin','service','api','pl-400'], 'teacher_john', 'teacher_john'),

('concept_pp_ipluginctx01', 'IPluginExecutionContext',
 'software',
 'The interface providing a plugin with information about the triggering event: input/output parameters, pre/post images, user IDs, and call depth.',
 'context.InputParameters["Target"] retrieves the Entity being created; context.UserId is the user whose action triggered the plugin.',
 'IPluginExecutionContext is like the HTTP request object in a web handler — it carries all the metadata about who triggered the event and what data is involved.',
 'Accessing context.InputParameters without null-checking; assuming the Target is an Entity when it could be an EntityReference for Delete messages.',
 ARRAY['plugin','context','execution','pl-400'], 'teacher_john', 'teacher_john'),

('concept_pp_svccontext01', 'OrganizationServiceContext',
 'software',
 'A LINQ-enabled proxy that wraps IOrganizationService, enabling strongly-typed entity queries and change tracking in plugin or custom code.',
 'Using a LINQ query via OrganizationServiceContext: context.AccountSet.Where(a => a.StateCode == AccountState.Active).ToList().',
 'OrganizationServiceContext is like Entity Framework for Dataverse — it wraps the service with LINQ support and identity-mapped object tracking.',
 'Loading large query results with OrganizationServiceContext without paging, causing memory issues; it is less efficient than QueryExpression for bulk reads.',
 ARRAY['plugin','linq','service','pl-400'], 'teacher_john', 'teacher_john'),

('concept_pp_virtualtable01', 'Virtual Table Provider',
 'software',
 'A plugin-based provider that maps an external data source into a Dataverse virtual table, enabling CRUD operations on external data via the standard API.',
 'A Virtual Table Provider plugin handles Retrieve and RetrieveMultiple for an ExternalProduct table, fetching live data from a REST API.',
 'A Virtual Table Provider is like a database view backed by an API — Dataverse shows it as a table, but the data actually lives somewhere else.',
 'Expecting filtering, sorting, and paging to work automatically — the provider plugin must manually implement these operations against the external source.',
 ARRAY['plugin','virtual-table','integration','pl-400'], 'teacher_john', 'teacher_john'),

('concept_pp_asyncplugin01', 'Asynchronous Plugin',
 'software',
 'A plugin step registered to run asynchronously after the transaction commits via the Async Service, not blocking the synchronous user operation.',
 'A Post-Operation async plugin generates a PDF report after an Invoice is created, running in the background without blocking the user.',
 'An async plugin is like submitting a print job — the user''s action completes immediately, and the long-running task processes in the background.',
 'Using async plugins for logic that must complete before the user sees the result; async plugins run after the transaction and may be delayed.',
 ARRAY['plugin','async','performance','pl-400'], 'teacher_john', 'teacher_john'),

('concept_pp_plugintrace01', 'Plugin Trace Log',
 'software',
 'A Dataverse feature that captures ITracingService output from plugins, written to the PluginTraceLog table for debugging failures.',
 'tracingService.Trace("Processing order {0}", order.Id) writes a message viewable in the Plugin Trace Log table after a failure.',
 'Plugin Trace Logs are like server-side console.log for Dataverse plugins — you write messages and read them after the fact to diagnose problems.',
 'Only enabling Plugin Trace Log in Development but forgetting it is off by default in Production, making production failures hard to diagnose.',
 ARRAY['plugin','debugging','trace','pl-400'], 'teacher_john', 'teacher_john'),

('concept_pp_sandbox01', 'Plugin Sandbox Mode',
 'software',
 'The isolated execution environment for plugins that restricts access to network, file system, and registry, enforcing security and stability.',
 'A sandboxed plugin cannot open a direct TCP socket or read from the file system; it can only call Dataverse via IOrganizationService or allowed HTTP endpoints.',
 'The plugin sandbox is like a containerized execution environment — it can do its job but cannot reach outside the approved set of system resources.',
 'Attempting file I/O or registry access in plugins, which is blocked by the sandbox and throws SecurityException at runtime.',
 ARRAY['plugin','sandbox','security','pl-400'], 'teacher_john', 'teacher_john'),

-- ── Group 8: Integration and APIs ────────────────────────────────────────────
('concept_pp_webapi01', 'Dataverse Web API',
 'software',
 'A RESTful API following the OData v4 standard that provides full CRUD, query, and custom message access to Dataverse data and metadata.',
 'GET /api/data/v9.2/accounts?$select=name,revenue&$filter=statecode eq 0 returns active Account names and revenues as JSON.',
 'The Dataverse Web API is like a universal remote control for your data — any HTTP client (browser, Postman, Python) can read and write Dataverse via standard REST calls.',
 'Not including the required OData-Version and Accept headers; forgetting to handle paging via @odata.nextLink for large result sets.',
 ARRAY['web-api','rest','odata','pl-400'], 'teacher_john', 'teacher_john'),

('concept_pp_odata01', 'OData Query Syntax',
 'software',
 'Standard URL query options ($filter, $select, $expand, $orderby, $top) used with the Dataverse Web API to retrieve and shape data.',
 'GET /accounts?$filter=revenue gt 1000000&$select=name,revenue&$top=10&$orderby=revenue desc returns the top 10 richest accounts.',
 'OData query options are like SQL clauses for URLs — $filter is WHERE, $select is SELECT, $orderby is ORDER BY, $top is LIMIT.',
 'Using single quotes incorrectly for GUIDs (use no quotes for Guid in $filter); forgetting $expand for related table columns in the same call.',
 ARRAY['odata','web-api','query','pl-400'], 'teacher_john', 'teacher_john'),

('concept_pp_customconn01', 'Custom Connector',
 'software',
 'A user-defined connector built from an OpenAPI definition that wraps any HTTP API for use in Power Apps and Power Automate.',
 'A Custom Connector for a weather API defines operations GetCurrentWeather and GetForecast, then can be used in Canvas Apps and flows like any built-in connector.',
 'A Custom Connector is like writing a driver for a new device — once the driver is written, Power Platform can talk to that API through a familiar interface.',
 'Not specifying authentication in the connector definition, causing every user to need to manually configure credentials; forgetting to test with the connection.',
 ARRAY['connector','custom','openapi','pl-400'], 'teacher_john', 'teacher_john'),

('concept_pp_openapi01', 'OpenAPI Definition',
 'software',
 'A machine-readable specification (Swagger/OpenAPI 2.0) that describes an API''s endpoints, parameters, and authentication for custom connectors.',
 'An OpenAPI 2.0 YAML file defines a /customers/{id} GET endpoint with an Authorization Bearer header and a 200 response schema for Custom Connector import.',
 'An OpenAPI definition is like a restaurant menu — it tells you exactly what dishes (endpoints) are available, what ingredients (parameters) you need, and what you get back.',
 'Importing OpenAPI 3.0 specs — Custom Connectors require OpenAPI 2.0 (Swagger); advanced features like callbacks or composition are not supported.',
 ARRAY['openapi','swagger','api','pl-400'], 'teacher_john', 'teacher_john'),

('concept_pp_webhook01', 'Webhook',
 'software',
 'A Dataverse service endpoint type that sends an HTTP POST to an external URL when a registered Dataverse event occurs.',
 'A Dataverse webhook sends a POST with the ExecutionContext JSON to an Azure Function URL every time a new Case is created.',
 'A webhook is like a push notification subscription — Dataverse calls your endpoint the moment an event happens, instead of you polling repeatedly.',
 'Not securing the webhook endpoint with a signature or secret; Dataverse webhooks do not retry on failure without additional configuration.',
 ARRAY['webhook','integration','event','pl-400'], 'teacher_john', 'teacher_john'),

('concept_pp_svcendpoint01', 'Service Endpoint',
 'software',
 'A Dataverse configuration that routes event messages to Azure Service Bus, Azure Event Hub, or a Webhook target for external integration.',
 'A Service Endpoint configured for an Azure Service Bus queue posts execution context messages for all Opportunity Create events to the bus.',
 'A Service Endpoint is like a post box address for Dataverse events — when an event fires, Dataverse delivers a message to that external address.',
 'Not registering the Service Endpoint in a solution — it will not be transported to other environments during deployment.',
 ARRAY['service-endpoint','azure','integration','pl-400'], 'teacher_john', 'teacher_john'),

('concept_pp_servicebus01', 'Azure Service Bus Integration',
 'software',
 'Dataverse can post event context messages to an Azure Service Bus queue or topic, enabling decoupled, async integration with external systems.',
 'A Service Bus-backed Service Endpoint sends order events to a queue; a separate Azure Function consumer processes them and writes to a data warehouse.',
 'Azure Service Bus integration is like a postal service between Dataverse and external systems — Dataverse drops messages in the mailbox and the consumer picks them up at its own pace.',
 'Assuming message ordering is guaranteed in Service Bus queues (it is not by default); use sessions for ordered processing.',
 ARRAY['azure-service-bus','integration','async','pl-400'], 'teacher_john', 'teacher_john'),

('concept_pp_oauth201', 'OAuth 2.0',
 'software',
 'The authorization protocol used by Power Platform to authenticate connectors and custom APIs, using client credentials or authorization code flows.',
 'A Custom Connector uses OAuth 2.0 Authorization Code flow; the user signs in once and the connector stores the token for subsequent API calls.',
 'OAuth 2.0 is like a hotel key card system — a central authority (Azure AD) issues a key (token) that grants access to specific rooms (APIs) without sharing your password.',
 'Hardcoding client secrets in connector or flow definitions instead of using Azure Key Vault references or Environment Variables.',
 ARRAY['oauth','security','authentication','pl-400'], 'teacher_john', 'teacher_john'),

('concept_pp_powerbi01', 'Power BI Embedded',
 'software',
 'Integration that embeds Power BI reports and dashboards inside Model-Driven App dashboards or forms for in-context analytics.',
 'A Model-Driven App dashboard shows a Power BI report filtered to the current user''s region, providing in-context analytics without leaving the app.',
 'Power BI Embedded in a Model-Driven App is like a live TV screen built into an office wall — the data visualization is part of the workspace, not a separate tool.',
 'Forgetting to configure row-level security (RLS) in Power BI; embedding reports that are not published to the correct Power BI workspace.',
 ARRAY['power-bi','analytics','model-driven','pl-400'], 'teacher_john', 'teacher_john'),

('concept_pp_powerpages01', 'Power Pages',
 'software',
 'A low-code platform for building externally-facing websites backed by Dataverse, with built-in authentication and Table Permissions.',
 'A Power Pages portal lets external suppliers log in to view and update their own Dataverse records, with Table Permissions controlling data access.',
 'Power Pages is like a customer-facing storefront window into Dataverse — external users see only what you choose to expose, secured by Table Permissions.',
 'Not setting up Table Permissions before going live; without them all Dataverse data is inaccessible to portal users by default.',
 ARRAY['power-pages','portal','web','pl-400'], 'teacher_john', 'teacher_john'),

-- ── Group 9: ALM and DevOps ───────────────────────────────────────────────────
('concept_pp_alm01', 'Application Lifecycle Management (ALM)',
 'software',
 'The practice of managing Power Platform solutions across Development, Test, and Production environments using automated pipelines and source control.',
 'A team maintains a Dev environment for development, a Sandbox for testing, and Production; pipelines automatically export from Dev and import to Sandbox.',
 'Power Platform ALM is like a software deployment pipeline — code (solutions) moves through stages (Dev → Test → Prod) with gates and automation at each step.',
 'Making direct customizations in Production instead of following the Dev → Test → Prod promotion pattern, leading to unmanaged components and drift.',
 ARRAY['alm','devops','deployment','pl-400'], 'teacher_john', 'teacher_john'),

('concept_pp_solchecker01', 'Solution Checker',
 'software',
 'A Power Platform tool that performs static analysis of solution components against a ruleset to identify performance, reliability, and upgrade issues.',
 'Running Solution Checker before release flags a plugin that calls an external URL synchronously in Pre-Operation as a high severity issue.',
 'Solution Checker is like a linter or SonarQube scan for Power Platform — it finds code smells, anti-patterns, and compliance violations before deployment.',
 'Ignoring Solution Checker warnings as optional — many issues it flags will cause failures in Managed Environments where enforcement is mandatory.',
 ARRAY['alm','quality','static-analysis','pl-400'], 'teacher_john', 'teacher_john'),

('concept_pp_ppcli01', 'Power Platform CLI (pac)',
 'software',
 'A cross-platform command-line tool for automating Power Platform tasks: exporting/importing solutions, managing environments, and scaffolding PCF projects.',
 'pac solution export --name MySolution --path ./solutions exports a solution zip; pac solution import --path ./solutions/MySolution.zip imports it.',
 'The pac CLI is like git for Power Platform solutions — it gives developers a command-line interface to manage environments and solutions in scripts and pipelines.',
 'Not authenticating with pac auth create before running commands; running pac commands outside the correct directory context.',
 ARRAY['cli','devops','pac','pl-400'], 'teacher_john', 'teacher_john'),

('concept_pp_azdevops01', 'Azure DevOps for Power Platform',
 'software',
 'Using Azure DevOps pipelines with the Power Platform Build Tools extension to automate solution export, check, import, and release across environments.',
 'A YAML pipeline uses the "Power Platform Export Solution" task to pull the solution from Dev, commits it to Git, then deploys to Test.',
 'Azure DevOps pipelines for Power Platform are like a factory conveyor belt — the solution enters one end in Dev and emerges packaged and tested in Production.',
 'Not storing service principal credentials securely in Azure DevOps variable groups (marked as secret); running pipelines as a named user instead of a service principal.',
 ARRAY['azure-devops','alm','pipeline','pl-400'], 'teacher_john', 'teacher_john'),

('concept_pp_ghactions01', 'GitHub Actions for Power Platform',
 'software',
 'A set of GitHub Actions (microsoft/powerplatform-actions) that automate solution packaging, publishing, and environment management in GitHub CI/CD workflows.',
 'A GitHub Actions workflow uses microsoft/powerplatform-actions/export-solution@v1 to export on push to main and microsoft/powerplatform-actions/import-solution@v1 to deploy.',
 'GitHub Actions for Power Platform is like a CI/CD pipeline that treats Power Platform solutions the same as code — with automated build, test, and deploy steps.',
 'Storing environment URLs and credentials directly in the workflow YAML file instead of using GitHub Secrets and Variables.',
 ARRAY['github-actions','alm','ci-cd','pl-400'], 'teacher_john', 'teacher_john'),

('concept_pp_envstrategy01', 'Environment Strategy',
 'software',
 'Planning and structuring Power Platform environments (Development, Sandbox, UAT, Production) to support team collaboration and safe deployments.',
 'Small team: Developer Sandbox → Shared Test → Production. Enterprise: Individual Dev → Integration → UAT → Pre-prod → Production.',
 'An environment strategy is like lanes in a swimming pool — each lane has a purpose (practice, warm-up, race), and mixing them causes chaos.',
 'Having only one environment and making changes directly in Production; not documenting which environments require managed solutions.',
 ARRAY['environment','alm','governance','pl-400'], 'teacher_john', 'teacher_john'),

('concept_pp_managedenv01', 'Managed Environment',
 'software',
 'A premium Power Platform feature enabling enhanced governance: weekly digest, usage insights, solution checker enforcement, and sharing limits.',
 'Managed Environment is enabled on Production; makers receive a weekly digest of unused apps, and Solution Checker is automatically enforced on imports.',
 'A Managed Environment is like a city with zoning laws — extra guardrails that automatically enforce policies and provide visibility beyond a standard environment.',
 'Enabling Managed Environments without reviewing the sharing limits and Solution Checker rules that will be automatically enforced.',
 ARRAY['environment','governance','admin','pl-400'], 'teacher_john', 'teacher_john'),

('concept_pp_sollayers01', 'Solution Layers',
 'software',
 'The stacked customization model in Dataverse where each solution adds a layer on top of base components; the active layer is the merged result.',
 'An ISV installs a managed solution; a customer adds an unmanaged customization on top. Viewing the Account form shows two layers: the ISV base and the customer override.',
 'Solution layers are like CSS specificity — multiple rules can target the same element, and the most specific (top layer) wins.',
 'Customizing managed solution components without understanding that removing the customization layer reverts to the ISV default, not deletes the component.',
 ARRAY['solution','layers','customization','pl-400'], 'teacher_john', 'teacher_john'),

('concept_pp_depcheck01', 'Dependency Checker',
 'software',
 'A Dataverse tool that identifies components that depend on or are required by a given solution component, preventing accidental deletion.',
 'Dependency Checker shows that removing the Priority column will break a Cloud Flow, a Business Rule, and a Plugin Step that all reference it.',
 'The Dependency Checker is like a "what uses this" feature in an IDE — before deleting a component, you see all the places that depend on it.',
 'Deleting components without running Dependency Checker first; this causes broken references that are difficult to diagnose after the fact.',
 ARRAY['solution','dependency','alm','pl-400'], 'teacher_john', 'teacher_john'),

('concept_pp_fieldsecp01', 'Field Security Profile',
 'software',
 'A Dataverse security construct that restricts which users or teams can read, create, or update specific sensitive columns on a table.',
 'A "Finance Only" Field Security Profile grants Read/Update on the Salary column to users in the Finance team and denies access to all others.',
 'A Field Security Profile is like column-level access control in a database — even if you can see the table, certain columns require an extra key.',
 'Confusing Field Security Profiles with regular security role column access; FSPs are additive — you must explicitly grant access to each team.',
 ARRAY['security','field','dataverse','pl-400'], 'teacher_john', 'teacher_john'),

-- ── Group 10: Security and Governance ────────────────────────────────────────
('concept_pp_dlp01', 'Data Loss Prevention (DLP) Policy',
 'software',
 'An admin-configured policy that classifies connectors into Business, Non-Business, or Blocked tiers to prevent unauthorized data exfiltration in flows.',
 'A DLP policy places SharePoint and Dataverse in the Business tier and Dropbox in Non-Business, blocking flows that combine both tiers.',
 'A DLP policy is like a building security checkpoint — it blocks certain combinations of services from passing data between each other without approval.',
 'Creating overly restrictive DLP policies that block legitimate business flows; test DLP policies in a sandbox before applying to Production.',
 ARRAY['dlp','governance','security','pl-400'], 'teacher_john', 'teacher_john'),

('concept_pp_admincenter01', 'Power Platform Admin Center',
 'software',
 'The web portal for managing environments, capacity, DLP policies, connectors, and tenant-level analytics across the Power Platform tenant.',
 'In Admin Center, an admin creates a new sandbox environment, applies a DLP policy, and monitors storage capacity across all environments.',
 'The Admin Center is like a control room for the entire Power Platform — all environments, policies, and tenant-level settings are managed from one place.',
 'Granting Power Platform Admin role broadly; use Environment Admin for environment-specific management and reserve tenant admin for tenant-wide policies.',
 ARRAY['admin','governance','portal','pl-400'], 'teacher_john', 'teacher_john'),

('concept_pp_coe01', 'Center of Excellence (CoE) Toolkit',
 'software',
 'A reference implementation of governance tooling deployed to a Power Platform environment to gain visibility, drive adoption, and enforce standards.',
 'After deploying the CoE Toolkit, admins see a Power BI dashboard showing all Canvas Apps, Flows, and Connectors in use across the tenant.',
 'The CoE Toolkit is like a governance dashboard for a city government — it gives leaders visibility into what is being built and by whom, so they can guide and govern effectively.',
 'Treating the CoE Toolkit as a finished product — it is a reference implementation that requires customization and ongoing maintenance.',
 ARRAY['coe','governance','toolkit','pl-400'], 'teacher_john', 'teacher_john'),

('concept_pp_tenantanalytics01', 'Tenant-level Analytics',
 'software',
 'Admin Center reports showing usage metrics across all environments: active users, flow runs, connector usage, and app launches at the tenant level.',
 'Tenant Analytics shows that 80% of active Cloud Flows in Production belong to three users, flagging a key-person dependency risk.',
 'Tenant Analytics is like a fitness tracker for your Power Platform tenant — it shows activity, usage patterns, and areas that need attention.',
 'Not reviewing analytics regularly; tenant analytics data has a lag (up to 28 days) and should not be used for real-time monitoring.',
 ARRAY['analytics','governance','admin','pl-400'], 'teacher_john', 'teacher_john'),

('concept_pp_managedid01', 'Managed Identity Authentication',
 'software',
 'Using Azure-managed identities (system-assigned or user-assigned) for Power Platform connectors and Azure resources to avoid storing credentials.',
 'An Azure Function triggered by Dataverse uses a system-assigned managed identity to authenticate to Azure Key Vault without any stored secrets.',
 'A managed identity is like an employee badge issued by the building (Azure) itself — the employee (service) does not need to carry a separate key (password).',
 'Using client secrets in connection strings when managed identities are available; secrets expire and rotate, managed identities are automatic.',
 ARRAY['security','managed-identity','azure','pl-400'], 'teacher_john', 'teacher_john'),

('concept_pp_apilimit01', 'API Request Limits',
 'software',
 'Per-user, per-day limits on Dataverse and connector API calls in Power Platform, with capacity add-ons available for high-volume workloads.',
 'A user with a per-user license gets 40,000 API requests per day; a flow that processes 50,000 rows daily requires a capacity add-on.',
 'API request limits are like a data plan on a phone — you get an allocation per period, and if you exceed it, performance is throttled or blocked.',
 'Not monitoring API consumption until throttling occurs in Production; building high-volume integrations without checking if capacity add-ons are needed.',
 ARRAY['licensing','limits','capacity','pl-400'], 'teacher_john', 'teacher_john'),

('concept_pp_licensing01', 'Power Platform Licensing',
 'software',
 'The licensing model covering per-app, per-user, and pay-as-you-go plans for Power Apps, plus premium connector and Dataverse capacity entitlements.',
 'A user with a Power Apps per-user plan can use all premium connectors and Dataverse; a user with Microsoft 365 only cannot use premium features.',
 'Power Platform licensing is like a tiered streaming service — the free tier gives basic features, the premium tier unlocks everything, and you pay per user or per app.',
 'Assuming Microsoft 365 licenses cover premium connectors or Dataverse; missing that Power Apps per-app licenses are per-app per-user, not per-tenant.',
 ARRAY['licensing','admin','governance','pl-400'], 'teacher_john', 'teacher_john'),

('concept_pp_dvteam01', 'Dataverse Team',
 'software',
 'A group of users in Dataverse (Owner, Access, or AAD Group team) that can be assigned security roles, simplifying bulk permission management.',
 'An "EMEA Sales" AAD Group Team is assigned the Sales Rep security role; all Azure AD group members automatically inherit the role in Dataverse.',
 'A Dataverse Team is like a user group in Active Directory mapped to Dataverse permissions — manage the group membership and the Dataverse access follows.',
 'Assigning security roles directly to individual users when teams should be used; direct assignments are harder to audit and maintain at scale.',
 ARRAY['security','team','dataverse','pl-400'], 'teacher_john', 'teacher_john'),

('concept_pp_hierarchysec01', 'Hierarchy Security',
 'software',
 'A Dataverse security model (Manager or Position hierarchy) that grants managers read or write access to their direct and indirect reports'' records.',
 'With Manager Hierarchy enabled, a regional manager can read all records owned by their direct reports even if the records are in a different BU.',
 'Hierarchy Security is like a reporting chain in an org chart — managers automatically get visibility into their reports'' work without explicit sharing.',
 'Enabling Hierarchy Security without setting the correct manager field on users; without the parent relationship set, the hierarchy model has no effect.',
 ARRAY['security','hierarchy','dataverse','pl-400'], 'teacher_john', 'teacher_john'),

('concept_pp_pad01', 'Power Automate Desktop (PAD)',
 'software',
 'The desktop application for building and running Desktop Flows locally, with a drag-and-drop designer and hundreds of built-in UI automation actions.',
 'A PAD flow opens Internet Explorer, navigates to a legacy HR portal, scrapes employee data from a table, and saves it to a Dataverse table.',
 'PAD is like teaching a robot to do exactly what a human does on a PC screen — every mouse click, keyboard entry, and window switch can be recorded and replayed.',
 'Not using attended vs unattended RPA correctly; unattended flows require an unattended add-on and a machine that is always on and logged in.',
 ARRAY['power-automate','desktop','rpa','pl-400'], 'teacher_john', 'teacher_john')

ON CONFLICT (id) DO NOTHING;

-- ---------------------------------------------------------------------------
-- Topics (10, one per group)
-- ---------------------------------------------------------------------------

INSERT INTO topics (id, name, folder_id, description, created_by, updated_by)
VALUES
    ('topic_pp_dvfund01', 'Dataverse Fundamentals',
     'folder_powerplatform01',
     'Core Dataverse concepts: tables, columns, relationships, solutions, publishers, and security roles.',
     'teacher_john', 'teacher_john'),

    ('topic_pp_dvadvanced01', 'Dataverse Advanced Features',
     'folder_powerplatform01',
     'Advanced Dataverse features: calculated/rollup columns, alternate keys, elastic tables, virtual columns, audit logs, and search.',
     'teacher_john', 'teacher_john'),

    ('topic_pp_powerapps01', 'Power Apps Development',
     'folder_powerplatform01',
     'Building Canvas and Model-Driven Apps: Power Fx, connectors, delegation, collections, galleries, and app design.',
     'teacher_john', 'teacher_john'),

    ('topic_pp_pcfclient01', 'PCF and Client Scripting',
     'folder_powerplatform01',
     'Extending the UI with PCF controls, TypeScript, React, Client API (Xrm), web resources, and command bar customization.',
     'teacher_john', 'teacher_john'),

    ('topic_pp_autofund01', 'Power Automate Fundamentals',
     'folder_powerplatform01',
     'Core Cloud Flow concepts: triggers, actions, conditions, loops, error handling, environment variables, and connection references.',
     'teacher_john', 'teacher_john'),

    ('topic_pp_bizauto01', 'Business Process Automation',
     'folder_powerplatform01',
     'Business Process Flows, business rules, custom actions, custom APIs, and the full range of flow types (scheduled, automated, instant, desktop, classic).',
     'teacher_john', 'teacher_john'),

    ('topic_pp_plugindev01', 'Plugin Development',
     'folder_powerplatform01',
     'Writing .NET plugins: steps, images, IOrganizationService, IPluginExecutionContext, async plugins, trace logs, and sandbox mode.',
     'teacher_john', 'teacher_john'),

    ('topic_pp_integration01', 'Integration and APIs',
     'folder_powerplatform01',
     'Integrating Power Platform via Web API, OData, custom connectors, OpenAPI, webhooks, service endpoints, Azure Service Bus, OAuth, Power BI, and Power Pages.',
     'teacher_john', 'teacher_john'),

    ('topic_pp_alm01', 'ALM and DevOps',
     'folder_powerplatform01',
     'Application lifecycle management: Solution Checker, pac CLI, Azure DevOps, GitHub Actions, environment strategy, solution layers, and field security profiles.',
     'teacher_john', 'teacher_john'),

    ('topic_pp_secgov01', 'Security and Governance',
     'folder_powerplatform01',
     'DLP policies, Admin Center, CoE Toolkit, tenant analytics, managed identities, API limits, licensing, Dataverse teams, and hierarchy security.',
     'teacher_john', 'teacher_john')
ON CONFLICT (id) DO NOTHING;

-- ---------------------------------------------------------------------------
-- Topic ↔ Concept mappings (10 concepts per topic = 100 total)
-- ---------------------------------------------------------------------------

INSERT INTO topic_concepts (topic_id, concept_id)
VALUES
    -- Dataverse Fundamentals
    ('topic_pp_dvfund01', 'concept_pp_dataverse01'),
    ('topic_pp_dvfund01', 'concept_pp_table01'),
    ('topic_pp_dvfund01', 'concept_pp_columntype01'),
    ('topic_pp_dvfund01', 'concept_pp_onetomany01'),
    ('topic_pp_dvfund01', 'concept_pp_manytomany01'),
    ('topic_pp_dvfund01', 'concept_pp_solution01'),
    ('topic_pp_dvfund01', 'concept_pp_publisher01'),
    ('topic_pp_dvfund01', 'concept_pp_managed01'),
    ('topic_pp_dvfund01', 'concept_pp_securityrole01'),
    ('topic_pp_dvfund01', 'concept_pp_businessunit01'),
    -- Dataverse Advanced Features
    ('topic_pp_dvadvanced01', 'concept_pp_calculated01'),
    ('topic_pp_dvadvanced01', 'concept_pp_rollup01'),
    ('topic_pp_dvadvanced01', 'concept_pp_altkey01'),
    ('topic_pp_dvadvanced01', 'concept_pp_elastictable01'),
    ('topic_pp_dvadvanced01', 'concept_pp_auditlog01'),
    ('topic_pp_dvadvanced01', 'concept_pp_dvsearch01'),
    ('topic_pp_dvadvanced01', 'concept_pp_virtualcol01'),
    ('topic_pp_dvadvanced01', 'concept_pp_choice01'),
    ('topic_pp_dvadvanced01', 'concept_pp_polylookup01'),
    ('topic_pp_dvadvanced01', 'concept_pp_tableperm01'),
    -- Power Apps Development
    ('topic_pp_powerapps01', 'concept_pp_canvasapp01'),
    ('topic_pp_powerapps01', 'concept_pp_mdapp01'),
    ('topic_pp_powerapps01', 'concept_pp_powerfx01'),
    ('topic_pp_powerapps01', 'concept_pp_connector01'),
    ('topic_pp_powerapps01', 'concept_pp_delegation01'),
    ('topic_pp_powerapps01', 'concept_pp_collection01'),
    ('topic_pp_powerapps01', 'concept_pp_gallery01'),
    ('topic_pp_powerapps01', 'concept_pp_appform01'),
    ('topic_pp_powerapps01', 'concept_pp_custompage01'),
    ('topic_pp_powerapps01', 'concept_pp_appdesigner01'),
    -- PCF and Client Scripting
    ('topic_pp_pcfclient01', 'concept_pp_pcf01'),
    ('topic_pp_pcfclient01', 'concept_pp_typescript01'),
    ('topic_pp_pcfclient01', 'concept_pp_reactpcf01'),
    ('topic_pp_pcfclient01', 'concept_pp_pcfmanifest01'),
    ('topic_pp_pcfclient01', 'concept_pp_xrm01'),
    ('topic_pp_pcfclient01', 'concept_pp_formevent01'),
    ('topic_pp_pcfclient01', 'concept_pp_fieldevent01'),
    ('topic_pp_pcfclient01', 'concept_pp_jswebres01'),
    ('topic_pp_pcfclient01', 'concept_pp_htmlwebres01'),
    ('topic_pp_pcfclient01', 'concept_pp_commandbar01'),
    -- Power Automate Fundamentals
    ('topic_pp_autofund01', 'concept_pp_cloudflow01'),
    ('topic_pp_autofund01', 'concept_pp_flowtrigger01'),
    ('topic_pp_autofund01', 'concept_pp_flowaction01'),
    ('topic_pp_autofund01', 'concept_pp_condition01'),
    ('topic_pp_autofund01', 'concept_pp_applytoeach01'),
    ('topic_pp_autofund01', 'concept_pp_errorhandling01'),
    ('topic_pp_autofund01', 'concept_pp_envvar01'),
    ('topic_pp_autofund01', 'concept_pp_connref01'),
    ('topic_pp_autofund01', 'concept_pp_approval01'),
    ('topic_pp_autofund01', 'concept_pp_childflow01'),
    -- Business Process Automation
    ('topic_pp_bizauto01', 'concept_pp_bpf01'),
    ('topic_pp_bizauto01', 'concept_pp_bpfstage01'),
    ('topic_pp_bizauto01', 'concept_pp_bizrule01'),
    ('topic_pp_bizauto01', 'concept_pp_custaction01'),
    ('topic_pp_bizauto01', 'concept_pp_customapi01'),
    ('topic_pp_bizauto01', 'concept_pp_scheduledflow01'),
    ('topic_pp_bizauto01', 'concept_pp_automatedflow01'),
    ('topic_pp_bizauto01', 'concept_pp_instantflow01'),
    ('topic_pp_bizauto01', 'concept_pp_desktopflow01'),
    ('topic_pp_bizauto01', 'concept_pp_classicwf01'),
    -- Plugin Development
    ('topic_pp_plugindev01', 'concept_pp_plugin01'),
    ('topic_pp_plugindev01', 'concept_pp_pluginstep01'),
    ('topic_pp_plugindev01', 'concept_pp_pluginimage01'),
    ('topic_pp_plugindev01', 'concept_pp_iorgservice01'),
    ('topic_pp_plugindev01', 'concept_pp_ipluginctx01'),
    ('topic_pp_plugindev01', 'concept_pp_svccontext01'),
    ('topic_pp_plugindev01', 'concept_pp_virtualtable01'),
    ('topic_pp_plugindev01', 'concept_pp_asyncplugin01'),
    ('topic_pp_plugindev01', 'concept_pp_plugintrace01'),
    ('topic_pp_plugindev01', 'concept_pp_sandbox01'),
    -- Integration and APIs
    ('topic_pp_integration01', 'concept_pp_webapi01'),
    ('topic_pp_integration01', 'concept_pp_odata01'),
    ('topic_pp_integration01', 'concept_pp_customconn01'),
    ('topic_pp_integration01', 'concept_pp_openapi01'),
    ('topic_pp_integration01', 'concept_pp_webhook01'),
    ('topic_pp_integration01', 'concept_pp_svcendpoint01'),
    ('topic_pp_integration01', 'concept_pp_servicebus01'),
    ('topic_pp_integration01', 'concept_pp_oauth201'),
    ('topic_pp_integration01', 'concept_pp_powerbi01'),
    ('topic_pp_integration01', 'concept_pp_powerpages01'),
    -- ALM and DevOps
    ('topic_pp_alm01', 'concept_pp_alm01'),
    ('topic_pp_alm01', 'concept_pp_solchecker01'),
    ('topic_pp_alm01', 'concept_pp_ppcli01'),
    ('topic_pp_alm01', 'concept_pp_azdevops01'),
    ('topic_pp_alm01', 'concept_pp_ghactions01'),
    ('topic_pp_alm01', 'concept_pp_envstrategy01'),
    ('topic_pp_alm01', 'concept_pp_managedenv01'),
    ('topic_pp_alm01', 'concept_pp_sollayers01'),
    ('topic_pp_alm01', 'concept_pp_depcheck01'),
    ('topic_pp_alm01', 'concept_pp_fieldsecp01'),
    -- Security and Governance
    ('topic_pp_secgov01', 'concept_pp_dlp01'),
    ('topic_pp_secgov01', 'concept_pp_admincenter01'),
    ('topic_pp_secgov01', 'concept_pp_coe01'),
    ('topic_pp_secgov01', 'concept_pp_tenantanalytics01'),
    ('topic_pp_secgov01', 'concept_pp_managedid01'),
    ('topic_pp_secgov01', 'concept_pp_apilimit01'),
    ('topic_pp_secgov01', 'concept_pp_licensing01'),
    ('topic_pp_secgov01', 'concept_pp_dvteam01'),
    ('topic_pp_secgov01', 'concept_pp_hierarchysec01'),
    ('topic_pp_secgov01', 'concept_pp_pad01')
ON CONFLICT (topic_id, concept_id) DO NOTHING;

-- =============================================================================
-- Microsoft Certified: Power Platform Fundamentals (PL-900)
-- Business Value — 60 concepts across 6 topics
-- =============================================================================

-- ---------------------------------------------------------------------------
-- Folder
-- ---------------------------------------------------------------------------

INSERT INTO folders (id, folder_type, owner_id, is_locked, name, description, domain, theme, icon, created_by, updated_by)
VALUES
    ('folder_pl900_01',
     'teacher', 'teacher_john', false,
     'Microsoft Certified: Power Platform Fundamentals (PL-900)',
     'Business value study material for the PL-900 exam: Power Platform overview, Power Apps, Power Automate, Power BI, Copilot Studio, and Microsoft Cloud integration.',
     'software', 'blue', 'star',
     'teacher_john', 'teacher_john')
ON CONFLICT (id) DO NOTHING;

INSERT INTO folder_members (folder_id, user_id, role, added_by)
VALUES
    ('folder_pl900_01', 'learner_alex', 'viewer', 'teacher_john'),
    ('folder_pl900_01', 'learner_mia',  'viewer', 'teacher_john')
ON CONFLICT (folder_id, user_id) DO NOTHING;

-- ---------------------------------------------------------------------------
-- 60 Concepts
-- ---------------------------------------------------------------------------

INSERT INTO concepts (id, canonical_name, domain, description, example,
analogy, common_mistakes, tags, created_by, updated_by)
VALUES

-- ── Group 1: Power Platform Overview & Business Value ────────────────────────
('concept_pl9_pp01', 'Microsoft Power Platform',
 'software',
 'A suite of low-code tools — Power Apps, Power Automate, Power BI, and Copilot Studio — that enables organisations to analyse data, build apps, automate processes, and create chatbots.',
 'A retail company uses Power BI to track sales, Power Apps for store audits, and Power Automate to send restock alerts — all without writing traditional code.',
 'Power Platform is like a Swiss Army knife for business problems — a set of purpose-built tools that work individually but are most powerful when used together.',
 'Thinking Power Platform replaces enterprise development entirely; it complements pro-code work but is not suited for every complex, high-scale scenario.',
 ARRAY['power-platform','overview','pl-900'], 'teacher_john', 'teacher_john'),

('concept_pl9_lowcode01', 'Low-Code / No-Code Development',
 'software',
 'An approach to building applications and automations using visual designers and configuration rather than hand-written code, dramatically lowering the skill barrier.',
 'A HR manager builds a leave-request app in Power Apps using drag-and-drop in an afternoon — no developer needed.',
 'Low-code development is like flat-pack furniture — the components are pre-engineered, and you assemble them visually rather than crafting each piece from raw materials.',
 'Assuming low-code means no governance or best practices; low-code apps still need security, ALM, and testing just like traditional software.',
 ARRAY['low-code','citizen-dev','pl-900'], 'teacher_john', 'teacher_john'),

('concept_pl9_citizendev01', 'Citizen Developer',
 'software',
 'A business user who builds apps or automations using low-code tools without a traditional software development background, empowered by platforms like Power Platform.',
 'A finance analyst builds a Power Apps expense-approval tool and a Power Automate flow to route approvals — without IT involvement.',
 'A citizen developer is like a self-taught home cook — not a professional chef, but capable of producing great results with the right kitchen tools and recipes.',
 'Citizen developers operating without guardrails (DLP, governance) can create shadow IT, security risks, and unsupported apps that break when the maker leaves.',
 ARRAY['citizen-dev','low-code','governance','pl-900'], 'teacher_john', 'teacher_john'),

('concept_pl9_digitaltx01', 'Digital Transformation',
 'software',
 'The process of using digital technology to fundamentally change how an organisation operates and delivers value, replacing manual or paper-based processes.',
 'A logistics company replaces paper delivery forms with a Power Apps mobile app and automatically updates Dataverse records in real time.',
 'Digital transformation is like replacing a paper filing cabinet with a searchable cloud database — the goal is the same but the speed, accuracy, and accessibility are transformed.',
 'Treating digital transformation as purely a technology project; it requires process redesign, change management, and leadership buy-in to succeed.',
 ARRAY['digital-transformation','business-value','pl-900'], 'teacher_john', 'teacher_john'),

('concept_pl9_dataverse_bv01', 'Dataverse Business Value',
 'software',
 'Dataverse provides a secure, scalable, standards-based data store shared across Power Platform apps, reducing data silos and enabling consistent business logic.',
 'A company stores customer data once in Dataverse and uses it across a Canvas App for sales reps, a Model-Driven App for support, and a Power BI report for managers.',
 'Dataverse is like a single source of truth for your organisation — instead of data scattered across spreadsheets and siloed apps, everything connects to one governed store.',
 'Confusing Dataverse with a simple database; its business value lies in built-in security, audit, API, and integration with the entire Power Platform ecosystem.',
 ARRAY['dataverse','data','pl-900'], 'teacher_john', 'teacher_john'),

('concept_pl9_environment01', 'Power Platform Environment',
 'software',
 'A container that holds Power Platform apps, flows, and Dataverse data, used to separate Development, Test, and Production workloads and control access.',
 'An organisation has a Dev environment for makers to experiment, a Test environment for UAT, and a Production environment that business users access daily.',
 'An environment is like a separate office floor — the same company (tenant) owns all floors, but each floor has its own apps, data, and access rules.',
 'Doing all work in the Default environment; it is shared across the entire tenant and has no isolation, making governance impossible.',
 ARRAY['environment','governance','pl-900'], 'teacher_john', 'teacher_john'),

('concept_pl9_m365int01', 'Microsoft 365 Integration',
 'software',
 'Power Platform integrates natively with Microsoft 365 services (Teams, SharePoint, Outlook, Excel) enabling apps and automations to extend familiar workplace tools.',
 'A Power Automate flow triggers when a new file is added to SharePoint, extracts data using AI Builder, and posts a summary to a Teams channel.',
 'M365 integration is like having Power Platform built into your existing office tools — you do not replace Teams or SharePoint, you extend them with apps and automation.',
 'Building standalone Power Apps when embedding them inside Teams or SharePoint would give users a more seamless, adoption-friendly experience.',
 ARRAY['microsoft-365','integration','pl-900'], 'teacher_john', 'teacher_john'),

('concept_pl9_azureint01', 'Azure Integration',
 'software',
 'Power Platform connects to Azure services (Azure SQL, Functions, Service Bus, Cognitive Services) enabling enterprise-grade capabilities within low-code solutions.',
 'A Canvas App connects to an Azure SQL database via a custom connector; a flow calls an Azure Function for heavy computation and returns the result.',
 'Azure integration is like a low-code app with a powerful engine under the hood — the Power Platform frontend is accessible to makers, while Azure handles the heavy lifting.',
 'Thinking Power Platform and Azure are competing alternatives; they are complementary — Power Platform for rapid development, Azure for complex back-end services.',
 ARRAY['azure','integration','pl-900'], 'teacher_john', 'teacher_john'),

('concept_pl9_d365int01', 'Dynamics 365 Integration',
 'software',
 'Power Platform extends Dynamics 365 CRM and ERP applications by adding custom apps, automations, and dashboards built on the shared Dataverse data layer.',
 'A sales team uses Dynamics 365 Sales for CRM; a maker adds a custom Canvas App for a simplified mobile view and a Power Automate flow for deal notifications.',
 'Dynamics 365 and Power Platform are like a smartphone and its app store — Dynamics 365 is the built-in platform, and Power Platform lets you build tailored extensions on top.',
 'Assuming Power Platform replaces Dynamics 365; they share the same Dataverse foundation and are designed to work together, not as alternatives.',
 ARRAY['dynamics-365','integration','pl-900'], 'teacher_john', 'teacher_john'),

('concept_pl9_tco01', 'Total Cost of Ownership (TCO)',
 'software',
 'The full cost of a technology solution including licences, development, maintenance, and training; Power Platform typically reduces TCO vs. custom-coded alternatives.',
 'A company estimates a custom app would cost £200k to build and £50k/year to maintain; the same solution on Power Platform costs £20k to build and £10k/year.',
 'TCO is like comparing the true cost of owning two cars — one cheaper to buy but expensive to service, one slightly pricier upfront but cheap to run long-term.',
 'Focusing only on licence cost while ignoring maker training, governance overhead, and support costs when calculating TCO for Power Platform.',
 ARRAY['tco','business-value','licensing','pl-900'], 'teacher_john', 'teacher_john'),

-- ── Group 2: Power Apps Business Value ───────────────────────────────────────
('concept_pl9_appsvalue01', 'Power Apps Business Value',
 'software',
 'Power Apps enables organisations to rapidly build custom business apps that replace paper forms, spreadsheets, and costly custom software with governed, mobile-ready solutions.',
 'A manufacturing firm replaces 12 paper-based inspection checklists with a single Canvas App, reducing data entry errors by 60% and eliminating manual data re-entry.',
 'Power Apps is like a DIY app store for your organisation — instead of waiting months for IT to build a solution, business teams can create and deploy their own in days.',
 'Underestimating app lifecycle management; Power Apps apps still need version control, testing, and owner succession plans to avoid abandoned apps.',
 ARRAY['power-apps','business-value','pl-900'], 'teacher_john', 'teacher_john'),

('concept_pl9_appmodern01', 'App Modernisation',
 'software',
 'Replacing legacy desktop applications, Access databases, or paper forms with modern Power Apps solutions that are mobile-friendly, cloud-hosted, and integrated with live data.',
 'An Access database used by 10 staff for inventory tracking is replaced by a Model-Driven App connected to Dataverse, accessible on any device.',
 'App modernisation is like renovating an old building — you keep the business function but replace the crumbling infrastructure with something safe, efficient, and scalable.',
 'Replicating the legacy app exactly instead of rethinking the process; modernisation is the ideal time to improve workflows, not just digitise old ones.',
 ARRAY['power-apps','modernisation','pl-900'], 'teacher_john', 'teacher_john'),

('concept_pl9_mobile01', 'Mobile-First Apps',
 'software',
 'Power Apps Canvas Apps are designed to run on iOS and Android devices, enabling field workers to access and update data from anywhere without a laptop.',
 'A site inspector uses a Canvas App on an iPhone to photograph defects, record measurements, and submit reports from the field — all syncing to Dataverse in real time.',
 'Mobile-first apps are like taking your office with you in your pocket — field workers get the same data access and input capabilities as desk-bound colleagues.',
 'Designing Canvas Apps for desktop first and scaling down; always design for the smallest screen (mobile) and scale up for tablet and desktop.',
 ARRAY['power-apps','mobile','field-worker','pl-900'], 'teacher_john', 'teacher_john'),

('concept_pl9_offline01', 'Offline Capability',
 'software',
 'Canvas Apps can store data locally when no internet connection is available, syncing changes back to the data source once connectivity is restored.',
 'A utility engineer uses a Canvas App in areas with no signal; completed inspection data is queued locally and uploaded automatically when the device reconnects.',
 'Offline capability is like a notepad that automatically emails your notes when you get back to the office — you capture data on the spot and sync happens later.',
 'Assuming offline capability is automatic; it requires deliberate design using SaveData(), LoadData(), and conflict resolution logic.',
 ARRAY['power-apps','offline','canvas','pl-900'], 'teacher_john', 'teacher_john'),

('concept_pl9_fusionteam01', 'Fusion Development Teams',
 'software',
 'A collaboration model where citizen developers (business users) and professional developers work together, with pros building reusable components and citizens assembling solutions.',
 'A pro developer builds a custom PCF control and an Azure API; a business analyst assembles these into a Canvas App using Power Platform without writing backend code.',
 'Fusion teams are like a construction project — architects and engineers design the structural systems, while skilled workers assemble the building from pre-made components.',
 'Treating fusion development as purely citizen-dev with no pro involvement; complex integrations and security requirements need professional developer oversight.',
 ARRAY['fusion-team','pro-dev','citizen-dev','pl-900'], 'teacher_john', 'teacher_john'),

('concept_pl9_powerpages_bv01', 'Power Pages Business Value',
 'software',
 'Power Pages enables organisations to build secure, externally-facing websites backed by Dataverse without traditional web development skills, extending data to partners and customers.',
 'A charity builds a volunteer sign-up portal on Power Pages where external users register, view their assignments, and submit reports — all stored in Dataverse.',
 'Power Pages is like a self-service customer portal built on top of your internal database — external users interact with your data through a safe, governed website.',
 'Forgetting that Table Permissions must be configured before going live; without them, portal users cannot read any Dataverse data at all.',
 ARRAY['power-pages','portal','business-value','pl-900'], 'teacher_john', 'teacher_john'),

('concept_pl9_rad01', 'Rapid Application Development (RAD)',
 'software',
 'The ability to build and deploy functional business apps in days or weeks rather than months, enabled by Power Apps'' visual development and pre-built templates.',
 'A project manager builds a risk-tracking app in one day using a Power Apps template, customises it over a week, and deploys it to the team the following Monday.',
 'RAD on Power Platform is like using LEGO blocks instead of raw bricks — the blocks are pre-shaped, so you spend time designing, not manufacturing.',
 'Sacrificing quality and governance for speed; RAD should still include data modelling, security review, and user acceptance testing before going live.',
 ARRAY['power-apps','rad','agile','pl-900'], 'teacher_john', 'teacher_john'),

('concept_pl9_aibuilder01', 'AI Builder',
 'software',
 'A Power Platform capability that brings pre-built and custom AI models (form processing, object detection, sentiment analysis) into apps and flows without data science expertise.',
 'A procurement team uses AI Builder''s invoice-processing model in a Power Automate flow to automatically extract line items from scanned PDF invoices.',
 'AI Builder is like a plug-in AI assistant for your apps and flows — you configure what you want to detect or extract, and the AI handles the complex model training.',
 'Expecting AI Builder models to be perfectly accurate out of the box; they require training data and ongoing refinement to reach production-ready accuracy.',
 ARRAY['ai-builder','ai','automation','pl-900'], 'teacher_john', 'teacher_john'),

('concept_pl9_template01', 'Power Apps Templates',
 'software',
 'Pre-built app templates in Power Apps (e.g. Expense Report, Issue Tracker, Asset Checkout) that give makers a working starting point to customise for their scenario.',
 'A facilities manager starts from the "Asset Checkout" template in Power Apps and customises it for their specific equipment categories and approval workflow in two days.',
 'Templates are like cookie-cutter moulds — they give you the right shape quickly, and you adapt the decoration (fields, logic, branding) to your needs.',
 'Using a template without understanding its data model; templates create their own tables and columns, which may conflict with existing Dataverse customisations.',
 ARRAY['power-apps','templates','pl-900'], 'teacher_john', 'teacher_john'),

('concept_pl9_appsgovernance01', 'Power Apps Governance',
 'software',
 'The policies, processes, and tools (DLP, environment strategy, CoE Toolkit) used to ensure Power Apps are secure, compliant, and maintainable across an organisation.',
 'An IT admin uses the CoE Toolkit to identify 200 unused Canvas Apps across the tenant and runs a cleanup campaign, saving storage and reducing security risk.',
 'Power Apps governance is like city planning — without zoning rules and building codes, citizen developers build wherever they like, leading to an unmanageable sprawl.',
 'Implementing governance only after problems arise; governance should be established before enabling broad citizen developer access to the platform.',
 ARRAY['governance','power-apps','admin','pl-900'], 'teacher_john', 'teacher_john'),

-- ── Group 3: Power Automate Business Value ────────────────────────────────────
('concept_pl9_autovalue01', 'Power Automate Business Value',
 'software',
 'Power Automate eliminates repetitive manual tasks, reduces human error, and frees employees to focus on higher-value work by automating business processes end-to-end.',
 'An HR team automates onboarding: when a new hire record is created in Dynamics 365, a flow sends welcome emails, creates accounts, and schedules orientation — saving 3 hours per hire.',
 'Power Automate is like a diligent office assistant who never sleeps — it handles routine tasks like sending emails, updating records, and routing approvals without being asked twice.',
 'Automating a broken process without first fixing it; automation amplifies both good and bad processes, so re-engineer before you automate.',
 ARRAY['power-automate','business-value','pl-900'], 'teacher_john', 'teacher_john'),

('concept_pl9_processauto01', 'Digital Process Automation (DPA)',
 'software',
 'Automating structured, rules-based business processes across digital systems using Cloud Flows, eliminating manual handoffs and reducing cycle times.',
 'A contract approval process that previously took 5 days of email chains is automated with a Power Automate approval flow, completing in hours with full audit trail.',
 'DPA is like replacing a relay race baton-pass with a conveyor belt — tasks move automatically to the next step without anyone needing to remember to hand off.',
 'Confusing DPA with RPA; DPA uses APIs and connectors to integrate systems directly, while RPA mimics user clicks on screens for legacy systems without APIs.',
 ARRAY['power-automate','dpa','automation','pl-900'], 'teacher_john', 'teacher_john'),

('concept_pl9_rpa_bv01', 'Robotic Process Automation (RPA) Business Value',
 'software',
 'RPA via Power Automate Desktop automates repetitive tasks on legacy desktop applications that lack APIs, bridging modern cloud workflows with older systems.',
 'A bank uses Desktop Flows to extract data from a 1990s mainframe terminal and populate a modern Dataverse table nightly — without modifying the mainframe.',
 'RPA is like a robotic arm bolted onto an old manual machine — the machine is not upgraded, but a robot now operates it automatically instead of a human.',
 'Using RPA when a proper API integration is available; RPA should be the last resort due to its fragility when the target UI changes.',
 ARRAY['rpa','power-automate','desktop','pl-900'], 'teacher_john', 'teacher_john'),

('concept_pl9_approvalvalue01', 'Approval Automation Business Value',
 'software',
 'Automating approval workflows (expenses, leave, contracts) with Power Automate eliminates email chains, provides auditability, and accelerates decision-making.',
 'A company replaces a 7-day email approval chain for purchase orders with a Power Automate approval flow that managers action in Microsoft Teams, reducing cycle time to 4 hours.',
 'Approval automation is like replacing a paper signature chain with a digital counter that instantly alerts the next approver the moment the previous one signs.',
 'Not handling rejection and escalation paths; approval flows must account for rejections, time-outs, and delegation to be production-ready.',
 ARRAY['power-automate','approval','business-value','pl-900'], 'teacher_john', 'teacher_john'),

('concept_pl9_roiautomation01', 'Automation ROI',
 'software',
 'The measurable return on investment from automating a process, calculated by comparing time/cost saved against the cost of building and maintaining the automation.',
 'Automating a 30-minute daily data entry task for 10 employees saves 150 hours/month; at £30/hour that is £4,500/month saved against a one-time build cost of £2,000.',
 'Automation ROI is like compound interest — small time savings per task multiply across employees and months into significant financial returns.',
 'Automating low-frequency, irregular tasks where the build cost outweighs the savings; focus first on high-volume, high-frequency repetitive processes.',
 ARRAY['power-automate','roi','business-value','pl-900'], 'teacher_john', 'teacher_john'),

('concept_pl9_processadvisor01', 'Process Mining',
 'software',
 'Power Automate''s process mining capability analyses event logs from business systems to discover how processes actually run, identify bottlenecks, and prioritise automation targets.',
 'Process mining on a purchase order system reveals that 40% of orders get stuck at the same approval step for more than 3 days, making it the top candidate for automation.',
 'Process mining is like a GPS that shows you the actual roads people are taking, not the intended route — it reveals where the real delays and detours are happening.',
 'Skipping process discovery and automating the assumed process; actual process behaviour often differs from documented procedures, leading to ineffective automations.',
 ARRAY['process-mining','power-automate','analytics','pl-900'], 'teacher_john', 'teacher_john'),

('concept_pl9_teamsauto01', 'Microsoft Teams Automation',
 'software',
 'Power Automate integrates with Microsoft Teams to send adaptive card notifications, trigger flows from messages, and post approvals directly inside the Teams interface.',
 'A Power Automate flow posts an adaptive card to a Teams channel when a high-priority support ticket is created, allowing the team to acknowledge it with one click.',
 'Teams automation is like adding a smart notification system to your team''s meeting room — important events surface automatically in the place where everyone already works.',
 'Building separate email-based notification flows when Teams is the primary communication tool for the team; meet users where they already work.',
 ARRAY['power-automate','teams','notification','pl-900'], 'teacher_john', 'teacher_john'),

('concept_pl9_errorreduce01', 'Error Reduction through Automation',
 'software',
 'Automating manual data entry and handoff tasks eliminates transcription errors, missed steps, and inconsistencies that are common in human-operated processes.',
 'Replacing manual copying of order data from emails into an ERP system with a Power Automate flow reduces data-entry errors from 5% to near zero.',
 'Automation for error reduction is like spell-check for business processes — it catches and prevents mistakes at the source rather than fixing them downstream.',
 'Assuming automation is error-free; automated flows need validation logic and exception handling to catch bad data before it propagates through systems.',
 ARRAY['power-automate','quality','business-value','pl-900'], 'teacher_john', 'teacher_john'),

('concept_pl9_scheduledauto01', 'Scheduled Automation',
 'software',
 'Running automations on a fixed schedule (daily, weekly, monthly) to handle batch operations like report generation, data synchronisation, and reminder notifications.',
 'A Scheduled Flow runs every Monday at 8 AM, pulls last week''s sales data from Dataverse, and emails a formatted summary report to each regional manager.',
 'Scheduled automation is like setting a recurring alarm for your business process — the task runs reliably at the same time every cycle without anyone needing to remember.',
 'Running scheduled flows that process all records every time instead of only changed records; always filter for incremental changes to avoid redundant processing.',
 ARRAY['power-automate','schedule','batch','pl-900'], 'teacher_john', 'teacher_john'),

('concept_pl9_connectorvalue01', 'Pre-Built Connectors Value',
 'software',
 'Power Automate provides 1,000+ pre-built connectors to popular services (Salesforce, SAP, ServiceNow, Office 365) enabling instant integration without custom development.',
 'A flow connects Salesforce (where leads arrive) to Dataverse (where they are managed) and Outlook (where the sales rep is notified) using three pre-built connectors — no code written.',
 'Pre-built connectors are like pre-wired electrical sockets — you plug your appliance (service) in without needing to understand the wiring behind the wall.',
 'Overlooking connector licensing tiers; many enterprise connectors (SAP, Salesforce) are Premium and require a higher licence tier beyond Microsoft 365.',
 ARRAY['power-automate','connectors','integration','pl-900'], 'teacher_john', 'teacher_john'),

-- ── Group 4: Power BI Business Value ─────────────────────────────────────────
('concept_pl9_bivalue01', 'Power BI Business Value',
 'software',
 'Power BI transforms raw data into interactive visualisations and reports that enable faster, evidence-based decisions across all levels of an organisation.',
 'A retail chain replaces weekly Excel-based sales reports emailed to managers with a live Power BI dashboard, cutting report preparation time from 8 hours to zero.',
 'Power BI is like upgrading from a printed map to a live GPS — instead of a static snapshot of where you were, you see exactly where you are and where you are heading.',
 'Building reports without understanding the audience; Power BI''s value comes from delivering the right insight to the right person, not creating the most complex dashboard.',
 ARRAY['power-bi','business-value','analytics','pl-900'], 'teacher_john', 'teacher_john'),

('concept_pl9_selfservicebi01', 'Self-Service BI',
 'software',
 'The ability for business users to create their own reports and dashboards from governed datasets without depending on IT or data analysts for every query.',
 'A marketing manager connects Power BI Desktop to a certified dataset and builds her own campaign-performance dashboard without raising an IT ticket.',
 'Self-service BI is like giving everyone in the office a key to the data filing cabinet — instead of asking IT to retrieve files, users find what they need themselves.',
 'Confusing self-service access with ungoverned data; self-service BI should be built on certified, IT-approved datasets to ensure consistent, trustworthy numbers.',
 ARRAY['power-bi','self-service','analytics','pl-900'], 'teacher_john', 'teacher_john'),

('concept_pl9_pbidesktop01', 'Power BI Desktop',
 'software',
 'A free Windows application for connecting to data sources, transforming data with Power Query, building data models, and authoring reports before publishing to the Power BI Service.',
 'A data analyst uses Power BI Desktop to connect to Azure SQL, clean data with Power Query, build a star-schema model, and design a sales report before publishing it.',
 'Power BI Desktop is like a professional kitchen where you prepare the meal (data model and report) before serving it (publishing to the service for others to consume).',
 'Doing all data transformation inside the report visuals instead of Power Query; complex calculations belong in the data model, not the visual layer.',
 ARRAY['power-bi','desktop','authoring','pl-900'], 'teacher_john', 'teacher_john'),

('concept_pl9_pbiservice01', 'Power BI Service',
 'software',
 'A cloud-based platform where published Power BI reports are shared, scheduled for data refresh, embedded, and consumed by business users across the organisation.',
 'A finance analyst publishes a monthly close dashboard to the Power BI Service, sets a daily data refresh, and shares it with the CFO''s team via a workspace.',
 'The Power BI Service is like a digital newsstand — the analyst (journalist) creates and publishes the report, and subscribers read it in the cloud on any device.',
 'Confusing Power BI Desktop (authoring tool) with the Power BI Service (publishing and sharing platform); they are separate tools with different roles.',
 ARRAY['power-bi','service','sharing','pl-900'], 'teacher_john', 'teacher_john'),

('concept_pl9_pbireport01', 'Power BI Report',
 'software',
 'A multi-page, interactive document created in Power BI Desktop containing visuals (charts, tables, maps) connected to a data model, enabling exploratory data analysis.',
 'A sales report contains a bar chart of revenue by region, a line chart of monthly trends, and a map of top customers — all filtering each other when clicked.',
 'A Power BI report is like an interactive magazine — instead of static printed charts, every visual is linked, and clicking one filters the others dynamically.',
 'Building one massive report with 20 pages; split by audience and purpose — simpler, focused reports are more adopted than comprehensive but confusing ones.',
 ARRAY['power-bi','report','visualisation','pl-900'], 'teacher_john', 'teacher_john'),

('concept_pl9_pbidashboard01', 'Power BI Dashboard',
 'software',
 'A single-page canvas in the Power BI Service that displays pinned tiles from multiple reports, providing a high-level real-time overview for executives and decision-makers.',
 'A CEO''s Power BI dashboard shows revenue-to-target, headcount, customer NPS, and open support tickets — all pinned from four different underlying reports.',
 'A Power BI dashboard is like a cockpit instrument panel — it shows the critical gauges from multiple systems in one glance, alerting you when something needs attention.',
 'Confusing a dashboard with a report; dashboards are a curated summary of KPIs pinned from reports, not a place to do exploratory analysis.',
 ARRAY['power-bi','dashboard','executive','pl-900'], 'teacher_john', 'teacher_john'),

('concept_pl9_datarefresh01', 'Data Refresh',
 'software',
 'The scheduled or on-demand process by which Power BI re-queries the data source and updates the report''s underlying dataset to reflect the latest information.',
 'A sales dashboard is configured with an 8x daily data refresh, so managers always see figures no more than 3 hours old without needing to manually update anything.',
 'Data refresh is like a newspaper printing a new edition — without it, readers see yesterday''s news; with a frequent schedule, the information stays current.',
 'Assuming reports show live data by default; Power BI imports data into a dataset, and without scheduled refresh the data becomes stale after the initial load.',
 ARRAY['power-bi','refresh','data','pl-900'], 'teacher_john', 'teacher_john'),

('concept_pl9_pbimobile01', 'Power BI Mobile',
 'software',
 'iOS and Android apps that allow business users to access Power BI dashboards and reports from their phones, with touch-optimised layouts and push notifications for alerts.',
 'A regional manager receives a push notification on his phone when the daily sales target falls below 80%, then opens Power BI Mobile to drill into the underperforming stores.',
 'Power BI Mobile is like carrying a live business newspaper in your pocket — you get alerts for breaking news (data anomalies) and can dig into the story anywhere.',
 'Not creating mobile-optimised report layouts; the default desktop layout is hard to read on a phone — use the mobile layout view in Power BI Desktop.',
 ARRAY['power-bi','mobile','analytics','pl-900'], 'teacher_john', 'teacher_john'),

('concept_pl9_datadriven01', 'Data-Driven Decision Making',
 'software',
 'The practice of basing business decisions on data analysis and visualisation rather than gut instinct, enabled by accessible tools like Power BI.',
 'A marketing team reviews a Power BI report showing which channels drive the lowest cost-per-lead, then reallocates budget from TV to digital — increasing leads by 30%.',
 'Data-driven decision making is like navigating with a map instead of guessing — you see the evidence, choose the most promising route, and measure whether it worked.',
 'Mistaking correlation for causation in data; Power BI surfaces patterns but humans must apply context and business knowledge to avoid drawing wrong conclusions.',
 ARRAY['power-bi','analytics','business-value','pl-900'], 'teacher_john', 'teacher_john'),

('concept_pl9_datasharing01', 'Power BI Sharing and Workspaces',
 'software',
 'Power BI Workspaces enable teams to collaborate on reports, and sharing features let analysts publish content to specific users or broad organisational audiences.',
 'A finance team uses a Power BI Workspace to co-develop reports; once approved, the content is published to an App for the wider business to consume in read-only mode.',
 'Workspaces are like a shared project folder — the team edits inside the workspace, and publishing an App is like printing the finished document for everyone to read.',
 'Sharing individual reports directly instead of publishing an App; direct sharing becomes unmanageable at scale and does not provide a curated, versioned experience.',
 ARRAY['power-bi','sharing','workspace','pl-900'], 'teacher_john', 'teacher_john'),

-- ── Group 5: Copilot Studio Business Value ────────────────────────────────────
('concept_pl9_copilotstudio01', 'Copilot Studio',
 'software',
 'A low-code platform for building AI-powered chatbots and copilots that can answer questions, automate tasks, and integrate with business data — without writing AI code.',
 'A customer service team builds a Copilot Studio bot that answers common product questions, looks up order status in Dataverse, and escalates complex issues to a human agent.',
 'Copilot Studio is like a smart receptionist you train with your own knowledge — you define the topics it knows about, and it handles customer queries automatically.',
 'Building a bot without defining a clear scope of what it should and should not answer; unbounded bots confuse users and are expensive to maintain.',
 ARRAY['copilot-studio','chatbot','ai','pl-900'], 'teacher_john', 'teacher_john'),

('concept_pl9_chatbot01', 'Chatbot Business Value',
 'software',
 'Chatbots built in Copilot Studio handle repetitive customer or employee queries 24/7, reducing support ticket volume and improving response times without increasing headcount.',
 'A company deploys an HR chatbot that answers 70% of common questions (leave balance, payslip access, policy queries) without human involvement, freeing HR staff for complex cases.',
 'A chatbot is like an always-available FAQ page that talks back — users get instant answers at any hour without waiting for a human to respond.',
 'Measuring chatbot success only by deflection rate; also measure customer satisfaction, escalation quality, and whether escalated cases are resolved faster.',
 ARRAY['copilot-studio','chatbot','business-value','pl-900'], 'teacher_john', 'teacher_john'),

('concept_pl9_intent01', 'Intent Recognition',
 'software',
 'The AI capability in Copilot Studio that understands the meaning behind a user''s message — even if phrased differently each time — and routes it to the correct topic.',
 'A user types "I need a day off next Friday" or "how do I book leave" — different phrasings that both trigger the same Leave Request topic in the bot.',
 'Intent recognition is like a well-trained customer service rep who understands what you mean even if you do not use the exact right words.',
 'Relying solely on intent AI without providing example phrases (trigger phrases); without enough examples, the model routes queries to wrong topics.',
 ARRAY['copilot-studio','nlp','ai','pl-900'], 'teacher_john', 'teacher_john'),

('concept_pl9_topics01', 'Copilot Studio Topics',
 'software',
 'A Topic in Copilot Studio defines a conversation path the bot follows when a user''s message matches its trigger phrases, containing questions, conditions, and actions.',
 'A "Track My Order" topic asks for the order number, calls a Power Automate flow to look up the status, and replies with the delivery date.',
 'Topics are like conversation scripts for the bot — when a user says the right trigger words, the bot follows the script for that scenario.',
 'Creating too many overlapping topics with similar trigger phrases, causing the bot to frequently route to the wrong topic or ask for disambiguation.',
 ARRAY['copilot-studio','topics','conversation','pl-900'], 'teacher_john', 'teacher_john'),

('concept_pl9_copilotactions01', 'Copilot Studio Actions',
 'software',
 'Actions in Copilot Studio connect a bot to real data and systems by calling Power Automate flows, HTTP APIs, or Dataverse queries within a conversation.',
 'During a conversation, the bot calls a Power Automate flow action to create a support ticket in Dataverse and returns the ticket number to the user.',
 'Actions are the bot''s hands — topics define what the bot says, while actions let it reach out and do things in connected systems on the user''s behalf.',
 'Putting all logic directly in the bot topic instead of a reusable Power Automate flow; flows are easier to test, maintain, and reuse across multiple topics.',
 ARRAY['copilot-studio','actions','integration','pl-900'], 'teacher_john', 'teacher_john'),

('concept_pl9_omnichannel01', 'Omnichannel Deployment',
 'software',
 'Copilot Studio bots can be published to multiple channels — Microsoft Teams, websites, mobile apps, Facebook, and more — from a single bot definition.',
 'A customer service bot is published to the company website and to Microsoft Teams simultaneously; employees and customers both use it but through their preferred channel.',
 'Omnichannel deployment is like broadcasting the same TV programme on multiple channels — the content is the same, but viewers choose their preferred screen.',
 'Building separate bots for each channel; one bot published to multiple channels is far more maintainable than maintaining parallel bots with duplicated logic.',
 ARRAY['copilot-studio','omnichannel','deployment','pl-900'], 'teacher_john', 'teacher_john'),

('concept_pl9_escalation01', 'Handoff to Live Agent',
 'software',
 'Copilot Studio can transfer a conversation to a human agent when the bot cannot resolve the query, passing full conversation context to avoid the user repeating themselves.',
 'When a customer''s complaint exceeds the bot''s capability, the bot transfers the full chat transcript to an available agent in Dynamics 365 Customer Service.',
 'Handoff to a live agent is like a receptionist transferring a call — the caller does not have to explain everything again because the receptionist briefs the next person.',
 'Not configuring escalation at all; every bot needs a graceful escalation path for queries it cannot handle, or users will abandon in frustration.',
 ARRAY['copilot-studio','escalation','customer-service','pl-900'], 'teacher_john', 'teacher_john'),

('concept_pl9_botanalytics01', 'Bot Analytics',
 'software',
 'Copilot Studio provides built-in analytics showing session volumes, resolution rates, escalation rates, and abandoned topics to help makers improve bot performance over time.',
 'Analytics show that 35% of sessions end in escalation on the "Billing" topic; the maker adds more phrases and answers to that topic, dropping escalation to 15%.',
 'Bot analytics are like a feedback form for your chatbot — they show which conversations went well, which fell flat, and exactly where to focus improvement efforts.',
 'Deploying a bot and never reviewing analytics; bots require continuous improvement based on real conversation data to maintain and improve resolution rates.',
 ARRAY['copilot-studio','analytics','improvement','pl-900'], 'teacher_john', 'teacher_john'),

('concept_pl9_knowledgebase01', 'Knowledge Base Integration',
 'software',
 'Copilot Studio can connect to SharePoint sites, public websites, or uploaded documents to automatically generate answers from existing organisational knowledge.',
 'A Copilot Studio bot is connected to the company''s SharePoint HR policy library; employees ask policy questions and the bot finds and summarises the relevant document.',
 'Knowledge base integration is like giving the bot a library card — instead of hand-crafting every answer, it reads from the organisation''s existing documents.',
 'Connecting the bot to unstructured or outdated knowledge bases; the quality of the bot''s answers is only as good as the quality of the source documents.',
 ARRAY['copilot-studio','knowledge-base','ai','pl-900'], 'teacher_john', 'teacher_john'),

('concept_pl9_generativeai01', 'Generative AI in Copilot Studio',
 'software',
 'Copilot Studio integrates generative AI (powered by Azure OpenAI) to allow bots to answer questions from connected knowledge sources using natural language generation.',
 'Without hand-crafting every topic, the bot reads from a SharePoint knowledge base and generates fluent, contextually relevant answers to employee policy questions.',
 'Generative AI in Copilot Studio is like upgrading from a scripted call centre to a knowledgeable human agent — responses are natural and context-aware, not rigid scripts.',
 'Relying entirely on generative AI without guardrails; configure topic-level controls and test thoroughly to prevent the bot from generating inaccurate or inappropriate responses.',
 ARRAY['copilot-studio','generative-ai','azure-openai','pl-900'], 'teacher_john', 'teacher_john'),

-- ── Group 6: Microsoft Cloud Ecosystem & Governance ──────────────────────────
('concept_pl9_mscloud01', 'Microsoft Cloud Ecosystem',
 'software',
 'The integrated set of Microsoft cloud services — Microsoft 365, Azure, Dynamics 365, and Power Platform — that share identity (Azure AD), data (Dataverse), and governance.',
 'A company uses Azure AD for identity, Microsoft 365 for productivity, Dynamics 365 for CRM, and Power Platform to build custom extensions — all governed from one tenant.',
 'The Microsoft Cloud is like a city built on one common infrastructure — roads (Azure), buildings (M365, D365), and custom extensions (Power Platform) all connect seamlessly.',
 'Treating each Microsoft cloud service as a standalone product; the strategic value comes from how they integrate, share data, and provide a unified governance model.',
 ARRAY['microsoft-cloud','ecosystem','integration','pl-900'], 'teacher_john', 'teacher_john'),

('concept_pl9_cdm01', 'Common Data Model (CDM)',
 'software',
 'A standardised, extensible collection of data schemas (Account, Contact, Product, Order) shared across Microsoft cloud services, enabling consistent data interpretation.',
 'The Account entity in Dynamics 365 CRM and the Account table in a custom Power Apps both use the same CDM schema, so data shared between them needs no translation.',
 'The Common Data Model is like a shared language for data — instead of each system speaking its own dialect, CDM gives every service the same vocabulary for common business entities.',
 'Ignoring CDM when designing custom tables; aligning custom schemas to CDM accelerates integration and makes data interoperable with Microsoft and third-party services.',
 ARRAY['cdm','data-model','interoperability','pl-900'], 'teacher_john', 'teacher_john'),

('concept_pl9_dvteams01', 'Dataverse for Teams',
 'software',
 'A lightweight version of Dataverse built into Microsoft Teams that lets users create simple apps and store data inside Teams without a full Power Platform licence.',
 'A team manager builds a simple meeting-action-tracker app inside Microsoft Teams using Dataverse for Teams — no additional licence needed beyond Microsoft 365.',
 'Dataverse for Teams is like a basic notebook built into Teams — enough for simple team-level apps, but you upgrade to full Dataverse when you need enterprise features.',
 'Assuming Dataverse for Teams has all the features of full Dataverse; it lacks advanced security roles, business rules, plugins, and large-scale capacity.',
 ARRAY['dataverse','teams','microsoft-365','pl-900'], 'teacher_john', 'teacher_john'),

('concept_pl9_security_bv01', 'Security and Compliance Value',
 'software',
 'Power Platform inherits Microsoft''s enterprise-grade security — Azure AD identity, role-based access, encryption at rest/transit, and compliance certifications (ISO, SOC, GDPR).',
 'A regulated financial firm adopts Power Platform knowing it meets FCA data residency requirements and integrates with their existing Azure AD conditional-access policies.',
 'Power Platform security is like renting office space in a Class A building — the core infrastructure (locks, fire systems, access control) is enterprise-grade from day one.',
 'Assuming platform-level security is sufficient without configuring app-level security roles and DLP policies; both layers are needed for a complete security posture.',
 ARRAY['security','compliance','governance','pl-900'], 'teacher_john', 'teacher_john'),

('concept_pl9_copilot_m365_01', 'Microsoft Copilot Integration',
 'software',
 'Microsoft Copilot (AI assistant powered by Azure OpenAI) is embedded across Microsoft 365, Dynamics 365, and Power Platform, enabling natural language interaction with business data.',
 'A sales manager asks Microsoft Copilot in Teams to summarise the last three customer calls and draft a follow-up email — Copilot pulls data from Dynamics 365 and M365.',
 'Microsoft Copilot is like a brilliant personal assistant who has read every document and email in your organisation and can find, summarise, and act on information instantly.',
 'Conflating Microsoft Copilot (M365 AI assistant) with Copilot Studio (bot-building platform); Copilot Studio is the tool for building custom copilots, not the AI assistant itself.',
 ARRAY['copilot','ai','microsoft-365','pl-900'], 'teacher_john', 'teacher_john'),

('concept_pl9_adoption01', 'Power Platform Adoption',
 'software',
 'The process of rolling out Power Platform across an organisation including training, community building (champions), governance setup, and demonstrating quick wins to build momentum.',
 'A company launches a Power Platform Centre of Excellence, trains 50 citizen developer champions, runs monthly hackathons, and tracks adoption via CoE Toolkit dashboards.',
 'Platform adoption is like planting a garden — you prepare the soil (governance), plant seeds (training and champions), water regularly (community and support), and harvest results (apps and automations).',
 'Deploying Power Platform without a structured adoption programme; without training, champions, and governance, the platform sees low usage or ungoverned sprawl.',
 ARRAY['adoption','governance','change-management','pl-900'], 'teacher_john', 'teacher_john'),

('concept_pl9_dlp_bv01', 'DLP Policy Business Value',
 'software',
 'Data Loss Prevention policies protect the organisation by preventing sensitive data from flowing to unauthorised external services via Power Apps or Power Automate connectors.',
 'A DLP policy blocks connectors that send data to consumer file-sharing services (Dropbox, Google Drive), ensuring corporate Dataverse data cannot be exfiltrated via flows.',
 'DLP policies are like a data customs officer — they inspect every flow''s connector connections and block packages from crossing the boundary to unapproved destinations.',
 'Setting DLP policies so restrictive that legitimate business automations are blocked, causing users to work around governance; balance security with productivity.',
 ARRAY['dlp','security','governance','pl-900'], 'teacher_john', 'teacher_john'),

('concept_pl9_sustainability01', 'Sustainability Value',
 'software',
 'Power Platform contributes to sustainability goals by replacing paper-based processes, reducing travel (digital approvals vs. in-person sign-offs), and running on Microsoft''s carbon-neutral cloud.',
 'Replacing 10,000 annual paper inspection forms with a Power Apps mobile solution eliminates paper waste and the associated printing, storage, and disposal costs.',
 'Digitalising processes on Power Platform is like switching from physical mail to email — the same information moves, but without the paper, printing, postage, and physical storage.',
 'Overstating sustainability impact without measurement; establish a baseline (paper used, travel taken) before digitalisation and measure actual reduction after.',
 ARRAY['sustainability','digital-transformation','business-value','pl-900'], 'teacher_john', 'teacher_john'),

('concept_pl9_community01', 'Power Platform Community',
 'software',
 'The global ecosystem of Power Platform users, MVPs, community forums, templates, and learning resources that accelerate skill development and problem-solving.',
 'A maker finds a community-built Power Apps template for project management on the Power Apps community gallery, saving two days of build time.',
 'The Power Platform community is like a global open-source library — millions of makers share templates, solutions, and answers so nobody has to solve the same problem twice.',
 'Not leveraging community resources before building from scratch; the Power Platform community gallery, Power Automate templates, and community forums resolve most common challenges.',
 ARRAY['community','learning','pl-900'], 'teacher_john', 'teacher_john')

ON CONFLICT (id) DO NOTHING;

-- ---------------------------------------------------------------------------
-- Topics (6, one per group)
-- ---------------------------------------------------------------------------

INSERT INTO topics (id, name, folder_id, description, created_by, updated_by)
VALUES
    ('topic_pl9_overview01', 'Power Platform Overview & Business Value',
     'folder_pl900_01',
     'The business case for Power Platform: low-code development, citizen developers, digital transformation, and integration with Microsoft 365, Azure, and Dynamics 365.',
     'teacher_john', 'teacher_john'),

    ('topic_pl9_appsvalue01', 'Power Apps Business Value',
     'folder_pl900_01',
     'How Power Apps delivers value: app modernisation, mobile-first field apps, rapid development, fusion teams, AI Builder, governance, and Power Pages portals.',
     'teacher_john', 'teacher_john'),

    ('topic_pl9_autovalue01', 'Power Automate Business Value',
     'folder_pl900_01',
     'How Power Automate delivers value: digital process automation, RPA, approval workflows, Teams integration, error reduction, and ROI measurement.',
     'teacher_john', 'teacher_john'),

    ('topic_pl9_bivalue01', 'Power BI Business Value',
     'folder_pl900_01',
     'How Power BI delivers value: self-service BI, reports vs dashboards, data refresh, mobile access, data-driven decisions, and workspace sharing.',
     'teacher_john', 'teacher_john'),

    ('topic_pl9_copilotvalue01', 'Copilot Studio Business Value',
     'folder_pl900_01',
     'How Copilot Studio delivers value: chatbot automation, intent recognition, topics, actions, omnichannel deployment, live agent handoff, analytics, and generative AI.',
     'teacher_john', 'teacher_john'),

    ('topic_pl9_ecosystem01', 'Microsoft Cloud Ecosystem & Governance',
     'folder_pl900_01',
     'The Microsoft Cloud platform: CDM, Dataverse for Teams, security and compliance, Microsoft Copilot, DLP policy value, adoption strategy, sustainability, and community.',
     'teacher_john', 'teacher_john')
ON CONFLICT (id) DO NOTHING;

-- ---------------------------------------------------------------------------
-- Topic ↔ Concept mappings (10 concepts per topic = 60 total)
-- ---------------------------------------------------------------------------

INSERT INTO topic_concepts (topic_id, concept_id)
VALUES
    -- Power Platform Overview
    ('topic_pl9_overview01', 'concept_pl9_pp01'),
    ('topic_pl9_overview01', 'concept_pl9_lowcode01'),
    ('topic_pl9_overview01', 'concept_pl9_citizendev01'),
    ('topic_pl9_overview01', 'concept_pl9_digitaltx01'),
    ('topic_pl9_overview01', 'concept_pl9_dataverse_bv01'),
    ('topic_pl9_overview01', 'concept_pl9_environment01'),
    ('topic_pl9_overview01', 'concept_pl9_m365int01'),
    ('topic_pl9_overview01', 'concept_pl9_azureint01'),
    ('topic_pl9_overview01', 'concept_pl9_d365int01'),
    ('topic_pl9_overview01', 'concept_pl9_tco01'),
    -- Power Apps Business Value
    ('topic_pl9_appsvalue01', 'concept_pl9_appsvalue01'),
    ('topic_pl9_appsvalue01', 'concept_pl9_appmodern01'),
    ('topic_pl9_appsvalue01', 'concept_pl9_mobile01'),
    ('topic_pl9_appsvalue01', 'concept_pl9_offline01'),
    ('topic_pl9_appsvalue01', 'concept_pl9_fusionteam01'),
    ('topic_pl9_appsvalue01', 'concept_pl9_powerpages_bv01'),
    ('topic_pl9_appsvalue01', 'concept_pl9_rad01'),
    ('topic_pl9_appsvalue01', 'concept_pl9_aibuilder01'),
    ('topic_pl9_appsvalue01', 'concept_pl9_template01'),
    ('topic_pl9_appsvalue01', 'concept_pl9_appsgovernance01'),
    -- Power Automate Business Value
    ('topic_pl9_autovalue01', 'concept_pl9_autovalue01'),
    ('topic_pl9_autovalue01', 'concept_pl9_processauto01'),
    ('topic_pl9_autovalue01', 'concept_pl9_rpa_bv01'),
    ('topic_pl9_autovalue01', 'concept_pl9_approvalvalue01'),
    ('topic_pl9_autovalue01', 'concept_pl9_roiautomation01'),
    ('topic_pl9_autovalue01', 'concept_pl9_processadvisor01'),
    ('topic_pl9_autovalue01', 'concept_pl9_teamsauto01'),
    ('topic_pl9_autovalue01', 'concept_pl9_errorreduce01'),
    ('topic_pl9_autovalue01', 'concept_pl9_scheduledauto01'),
    ('topic_pl9_autovalue01', 'concept_pl9_connectorvalue01'),
    -- Power BI Business Value
    ('topic_pl9_bivalue01', 'concept_pl9_bivalue01'),
    ('topic_pl9_bivalue01', 'concept_pl9_selfservicebi01'),
    ('topic_pl9_bivalue01', 'concept_pl9_pbidesktop01'),
    ('topic_pl9_bivalue01', 'concept_pl9_pbiservice01'),
    ('topic_pl9_bivalue01', 'concept_pl9_pbireport01'),
    ('topic_pl9_bivalue01', 'concept_pl9_pbidashboard01'),
    ('topic_pl9_bivalue01', 'concept_pl9_datarefresh01'),
    ('topic_pl9_bivalue01', 'concept_pl9_pbimobile01'),
    ('topic_pl9_bivalue01', 'concept_pl9_datadriven01'),
    ('topic_pl9_bivalue01', 'concept_pl9_datasharing01'),
    -- Copilot Studio Business Value
    ('topic_pl9_copilotvalue01', 'concept_pl9_copilotstudio01'),
    ('topic_pl9_copilotvalue01', 'concept_pl9_chatbot01'),
    ('topic_pl9_copilotvalue01', 'concept_pl9_intent01'),
    ('topic_pl9_copilotvalue01', 'concept_pl9_topics01'),
    ('topic_pl9_copilotvalue01', 'concept_pl9_copilotactions01'),
    ('topic_pl9_copilotvalue01', 'concept_pl9_omnichannel01'),
    ('topic_pl9_copilotvalue01', 'concept_pl9_escalation01'),
    ('topic_pl9_copilotvalue01', 'concept_pl9_botanalytics01'),
    ('topic_pl9_copilotvalue01', 'concept_pl9_knowledgebase01'),
    ('topic_pl9_copilotvalue01', 'concept_pl9_generativeai01'),
    -- Microsoft Cloud Ecosystem & Governance
    ('topic_pl9_ecosystem01', 'concept_pl9_mscloud01'),
    ('topic_pl9_ecosystem01', 'concept_pl9_cdm01'),
    ('topic_pl9_ecosystem01', 'concept_pl9_dvteams01'),
    ('topic_pl9_ecosystem01', 'concept_pl9_security_bv01'),
    ('topic_pl9_ecosystem01', 'concept_pl9_copilot_m365_01'),
    ('topic_pl9_ecosystem01', 'concept_pl9_adoption01'),
    ('topic_pl9_ecosystem01', 'concept_pl9_dlp_bv01'),
    ('topic_pl9_ecosystem01', 'concept_pl9_sustainability01'),
    ('topic_pl9_ecosystem01', 'concept_pl9_community01'),
    ('topic_pl9_ecosystem01', 'concept_pl9_tco01')
ON CONFLICT (topic_id, concept_id) DO NOTHING;
