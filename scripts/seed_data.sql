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
     'power platform', 'purple', 'cloud',
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
 'power platform',
 'Cloud-based data storage platform used by Power Platform apps to securely store and manage business data.',
 'A sales app stores Account, Contact, and Opportunity records in Dataverse tables, with row-level access controlled by security roles.',
 'Dataverse is like a managed database service built into Power Platform — similar to SQL Server but with built-in security, API, and auditing.',
 'Treating Dataverse like a plain SQL database and ignoring its abstracted API and security model; confusing it with SharePoint lists.',
 ARRAY['dataverse','power-platform','pl-400'], 'teacher_john', 'teacher_john'),

('concept_pp_table01', 'Dataverse Table',
 'power platform',
 'A structured container of rows and columns in Dataverse, equivalent to a database table, formerly called an Entity.',
 'The built-in Account table stores company data; a custom Work Order table stores field service requests.',
 'A Dataverse table is like a spreadsheet worksheet — rows are records and columns are fields — but with enforced data types and relationships.',
 'Calling it an "Entity" (the old name) in documentation targeting newer audiences; creating custom tables when standard tables already exist.',
 ARRAY['dataverse','table','schema','pl-400'], 'teacher_john', 'teacher_john'),

('concept_pp_columntype01', 'Column Data Types',
 'power platform',
 'The set of available column types in Dataverse: Text, Number, Date/Time, Choice, Lookup, Currency, File, and Image.',
 'A Customer Name column uses Text; a Revenue column uses Currency; a Status column uses Choice; a Manager column uses Lookup.',
 'Choosing a column type is like choosing the right container — you would not store water in a paper bag or screws in a liquid bottle.',
 'Using Text for numbers or dates, making filtering and calculations unreliable; confusing Choice (local) with Global Choice.',
 ARRAY['dataverse','column','schema','pl-400'], 'teacher_john', 'teacher_john'),

('concept_pp_onetomany01', 'One-to-Many Relationship',
 'power platform',
 'A Dataverse table relationship where one row in a parent table relates to multiple rows in a child table via a Lookup column.',
 'One Account can have many Contacts; the Contact table has a Lookup column pointing back to the parent Account.',
 'A one-to-many relationship is like a parent with children — one parent can have many children, but each child has one parent.',
 'Confusing the parent (one) and child (many) sides; forgetting to set cascade behaviors for delete and assign operations.',
 ARRAY['dataverse','relationship','schema','pl-400'], 'teacher_john', 'teacher_john'),

('concept_pp_manytomany01', 'Many-to-Many Relationship',
 'power platform',
 'A Dataverse relationship where rows in two tables can each be associated with multiple rows in the other, backed by an intersect table.',
 'A Contact can be associated with many Events, and an Event can have many Contacts, backed by a contact_event intersect table.',
 'Like students and courses — one student takes many courses, and one course has many students, tracked via an enrollment record.',
 'Trying to add extra columns to the intersect table when using native N:N relationships; use a custom intersect table when extra data is needed.',
 ARRAY['dataverse','relationship','schema','pl-400'], 'teacher_john', 'teacher_john'),

('concept_pp_solution01', 'Solution',
 'power platform',
 'A container for Power Platform customizations used to package and transport components (apps, flows, tables) across environments.',
 'A Field Service solution contains the WorkOrder table, a Canvas App, two Cloud Flows, and a security role, all packaged together for deployment.',
 'A solution is like a ZIP file or installer package — it groups all the customizations together so they can be moved as one unit.',
 'Adding components to the Default Solution instead of a proper solution, making them impossible to transport cleanly.',
 ARRAY['alm','solution','power-platform','pl-400'], 'teacher_john', 'teacher_john'),

('concept_pp_publisher01', 'Solution Publisher',
 'power platform',
 'Defines the customization prefix (e.g. "contoso_") applied to all solution components; identifies the vendor of a solution.',
 'Publisher "Contoso" with prefix "con" means all custom tables and columns get names like con_WorkOrder, con_Priority.',
 'A publisher prefix is like a namespace in code — it prevents naming collisions between solutions from different vendors.',
 'Using the default publisher prefix "new_" in production solutions; changing the prefix after components have already been created.',
 ARRAY['alm','solution','prefix','pl-400'], 'teacher_john', 'teacher_john'),

('concept_pp_managed01', 'Managed vs Unmanaged Solution',
 'power platform',
 'Managed solutions are locked, distributable packages; unmanaged solutions allow direct customization and are used during development.',
 'Developers work in an unmanaged solution in Dev; the pipeline exports a managed solution and imports it into UAT and Production.',
 'Unmanaged is like source code you can edit; managed is like a compiled binary you can install but not modify directly.',
 'Customizing managed solution components directly in Production; importing an unmanaged solution into Production.',
 ARRAY['alm','solution','deployment','pl-400'], 'teacher_john', 'teacher_john'),

('concept_pp_securityrole01', 'Security Role',
 'power platform',
 'A set of privileges that define what operations (Create, Read, Update, Delete) a user can perform on Dataverse tables.',
 'A "Sales Representative" security role grants Read/Create/Update on Opportunity at user level and Read on Account at business unit level.',
 'A security role is like a job access badge — it defines which doors (tables and operations) the badge holder can open.',
 'Editing the System Administrator role; not testing roles with the Check Access feature; giving global access when user-level is sufficient.',
 ARRAY['security','dataverse','access-control','pl-400'], 'teacher_john', 'teacher_john'),

('concept_pp_businessunit01', 'Business Unit',
 'power platform',
 'A hierarchical organizational unit in Dataverse used to group users and control data access scope through security roles.',
 'A global company creates Business Units for each region; a user in the EMEA BU can only see records owned by other EMEA users.',
 'Business Units are like departments in an org chart — they define which team a user belongs to and what data that team can access.',
 'Placing all users in the root BU, losing the ability to scope data access by team or region.',
 ARRAY['security','dataverse','organization','pl-400'], 'teacher_john', 'teacher_john'),

-- ── Group 2: Dataverse Advanced Features ─────────────────────────────────────
('concept_pp_calculated01', 'Calculated Column',
 'power platform',
 'A Dataverse column whose value is automatically computed from a formula referencing other columns in the same row.',
 'A Full Name column calculated as FirstName + " " + LastName; a Days Open column calculated as TODAY() minus CreatedOn.',
 'Like a formula cell in Excel — you define the formula once and it always shows the computed result based on sibling cells.',
 'Using a Calculated Column for values that need to be searchable or filterable efficiently; they cannot reference related table columns.',
 ARRAY['dataverse','column','formula','pl-400'], 'teacher_john', 'teacher_john'),

('concept_pp_rollup01', 'Rollup Column',
 'power platform',
 'A Dataverse column that aggregates values (sum, count, min, max, avg) from related child rows on a scheduled basis.',
 'Total Revenue on an Account row rolls up the sum of all closed Opportunity amounts related to that account, recalculated every 12 hours.',
 'Like a subtotal row at the bottom of a spreadsheet that automatically sums the child rows above it.',
 'Expecting real-time updates — rollup columns are asynchronous; using them in plugins where freshness is critical.',
 ARRAY['dataverse','column','aggregation','pl-400'], 'teacher_john', 'teacher_john'),

('concept_pp_altkey01', 'Alternate Key',
 'power platform',
 'A unique key defined on one or more columns that can identify a Dataverse row without using the primary GUID, used for upsert operations.',
 'An Order table has an alternate key on OrderNumber, enabling upsert calls like PATCH /orders(OrderNumber=''ORD-001'').',
 'An alternate key is like using an employee badge number instead of an internal employee ID to look someone up — unique and meaningful to the caller.',
 'Defining alternate keys on columns with duplicate or null values; not using them in integration upsert calls, causing duplicate record creation.',
 ARRAY['dataverse','schema','upsert','pl-400'], 'teacher_john', 'teacher_john'),

('concept_pp_elastictable01', 'Elastic Table',
 'power platform',
 'A Dataverse table type built on Azure Cosmos DB, designed for high-volume, high-velocity scenarios with flexible schemas.',
 'IoT sensor readings and telemetry events stored in an elastic table can handle millions of inserts per day with flexible JSON schemas.',
 'An elastic table is like a NoSQL document store plugged into Dataverse — great for high-volume, schema-variable data, unlike relational standard tables.',
 'Using elastic tables for relational data or workflows requiring transactional consistency; they do not support plugins or business rules.',
 ARRAY['dataverse','table','nosql','pl-400'], 'teacher_john', 'teacher_john'),

('concept_pp_auditlog01', 'Audit Log',
 'power platform',
 'Dataverse feature that records who created, modified, or deleted records and when, for compliance and troubleshooting.',
 'Enabling audit on the Contact table records every field change with the old and new value, who changed it, and when.',
 'An audit log is like CCTV footage for your data — you can replay exactly who changed what and when.',
 'Enabling audit on all tables and columns without considering storage costs; forgetting to configure the audit log retention period.',
 ARRAY['dataverse','audit','governance','pl-400'], 'teacher_john', 'teacher_john'),

('concept_pp_dvsearch01', 'Dataverse Search',
 'power platform',
 'A full-text, relevance-based search service across multiple Dataverse tables, powered by Azure Cognitive Search.',
 'Searching "Contoso" across Account, Contact, and Opportunity tables returns ranked results based on relevance across all configured tables.',
 'Dataverse Search is like a search engine for your Dataverse data — it finds relevant records across multiple tables, not just one at a time.',
 'Confusing Dataverse Search with Quick Find (single-table keyword search); tables and columns must be explicitly enabled for Dataverse Search.',
 ARRAY['dataverse','search','full-text','pl-400'], 'teacher_john', 'teacher_john'),

('concept_pp_virtualcol01', 'Virtual Column',
 'power platform',
 'A Dataverse column that retrieves its value from an external data source at query time without storing data in Dataverse.',
 'A virtual Currency column on a Quote table retrieves the live exchange rate from an external finance API each time the record is opened.',
 'A virtual column is like a live link in a spreadsheet that pulls data from an external source each time you view it, never storing a copy locally.',
 'Filtering or sorting on virtual columns — they are computed at read time and do not support server-side query operations.',
 ARRAY['dataverse','column','virtual','pl-400'], 'teacher_john', 'teacher_john'),

('concept_pp_choice01', 'Choice Column',
 'power platform',
 'A Dataverse column type (formerly Option Set) that stores a value from a predefined list of integer-label pairs.',
 'A Status column with choices: Active (1), Inactive (2), Pending (3). Code references the integer value; the UI displays the label.',
 'A Choice column is like a dropdown menu where each visible option maps to a hidden integer stored in the database.',
 'Hardcoding integer values in code instead of using the generated enum constants; confusing a local Choice with a reusable Global Choice.',
 ARRAY['dataverse','column','option-set','pl-400'], 'teacher_john', 'teacher_john'),

('concept_pp_polylookup01', 'Polymorphic Lookup',
 'power platform',
 'A Lookup column in Dataverse that can reference rows from more than one table type (e.g. Customer lookup to Account or Contact).',
 'The built-in Regarding column on Activity tables is polymorphic — it can point to an Account, a Contact, a Lead, or a custom table.',
 'A polymorphic lookup is like a universal remote control — one physical remote that can point to a TV, a soundbar, or a streaming box.',
 'Forgetting to filter the lookup view to the expected table types; complex filtering logic is needed in client-side code.',
 ARRAY['dataverse','relationship','lookup','pl-400'], 'teacher_john', 'teacher_john'),

('concept_pp_tableperm01', 'Table Permission',
 'power platform',
 'A Power Pages security construct that grants website users access to Dataverse table rows based on scope (Global, Contact, Account, etc.).',
 'A "Self" scoped Table Permission on Contact allows a Power Pages user to read and update only their own Contact record.',
 'Table Permissions are like bouncer rules at a website — they determine which Dataverse records external website users are allowed to see or edit.',
 'Granting Global scope Table Permissions unintentionally, exposing all records to all authenticated website users.',
 ARRAY['power-pages','security','dataverse','pl-400'], 'teacher_john', 'teacher_john'),

-- ── Group 3: Power Apps Development ──────────────────────────────────────────
('concept_pp_canvasapp01', 'Canvas App',
 'power platform',
 'A Power Apps application built on a blank canvas where developers control every UI element, layout, and behavior using Power Fx formulas.',
 'A field technician app with a custom gallery of work orders, a details screen, and a camera control for capturing photos, built on a blank canvas.',
 'Building a Canvas App is like designing a PowerPoint slide deck with live data connections — you control every pixel and interaction.',
 'Not designing for delegation early; nesting too many galleries causing performance issues; storing sensitive data in global variables.',
 ARRAY['power-apps','canvas','pl-400'], 'teacher_john', 'teacher_john'),

('concept_pp_mdapp01', 'Model-Driven App',
 'power platform',
 'A Power Apps application generated from Dataverse metadata, automatically rendering forms, views, charts, and dashboards.',
 'A CRM app generated from Account, Contact, and Opportunity tables, showing auto-generated forms, views, and dashboards based on metadata.',
 'A Model-Driven App is like a ready-made house interior — Dataverse is the blueprint, and Power Apps renders the furniture (forms, views) automatically.',
 'Trying to control pixel-level layout as with Canvas Apps; MDA layout is controlled by metadata, not a design canvas.',
 ARRAY['power-apps','model-driven','dataverse','pl-400'], 'teacher_john', 'teacher_john'),

('concept_pp_powerfx01', 'Power Fx Formula',
 'power platform',
 'The low-code formula language used in Canvas Apps, inspired by Excel, for defining logic, data operations, and navigation.',
 'Filter(Accounts, StartsWith(Name, TextInput1.Text)) filters an Accounts gallery as the user types; Patch() saves changes back to Dataverse.',
 'Power Fx is like Excel formulas but for app logic — familiar syntax extended with app actions like navigation, data writes, and variable management.',
 'Writing imperative code patterns (loops, variables) instead of leveraging functional/declarative Power Fx; overusing global variables.',
 ARRAY['power-apps','power-fx','formula','pl-400'], 'teacher_john', 'teacher_john'),

('concept_pp_connector01', 'Connector',
 'power platform',
 'A proxy wrapper around an external API that Power Apps and Power Automate use to communicate with services like SharePoint, SQL, or custom APIs.',
 'The SharePoint connector connects a Canvas App to a SharePoint list; the SQL Server connector streams records from an Azure SQL database.',
 'A connector is like a universal adapter plug — it translates between Power Apps''s standard interface and the specific API of each external service.',
 'Ignoring connector premium tier costs when selecting Standard vs Premium connectors; each data call counts against API limits.',
 ARRAY['power-apps','connector','integration','pl-400'], 'teacher_john', 'teacher_john'),

('concept_pp_delegation01', 'Delegation',
 'power platform',
 'The ability for a Canvas App data function to push query processing to the data source rather than downloading all records locally, avoiding the row limit.',
 'Filter(Accounts, Status = "Active") delegates to Dataverse and returns matching records server-side. Search() on a local collection is not delegable.',
 'Delegation is like asking the library to find books on a topic versus downloading the entire catalog and searching it yourself at home.',
 'Using non-delegable functions (Search, CountIf on some sources) on large datasets, triggering the 500/2000-row data row limit silently.',
 ARRAY['power-apps','performance','data','pl-400'], 'teacher_john', 'teacher_john'),

('concept_pp_collection01', 'Collection',
 'power platform',
 'An in-memory table stored locally in a Canvas App, created with Collect() or ClearCollect(), used for caching or staging data.',
 'ClearCollect(MyOrders, Filter(Orders, Owner = User().Email)) caches the user''s orders in a local collection for fast screen navigation.',
 'A Collection is like a shopping cart — a temporary local store that holds data for the session, not permanently saved anywhere.',
 'Treating collections as persistent storage — they are cleared when the app closes; using Collect() instead of ClearCollect() and accumulating duplicates.',
 ARRAY['power-apps','canvas','data','pl-400'], 'teacher_john', 'teacher_john'),

('concept_pp_gallery01', 'Gallery Control',
 'power platform',
 'A Canvas App control that displays a scrollable list of records where each item shares the same layout template.',
 'A Gallery bound to a Customers table displays each customer''s name, photo, and last contact date using a template that repeats per row.',
 'A Gallery is like a physical bulletin board with repeating card slots — you design one card template and the board fills in the data automatically.',
 'Using ThisItem inside nested galleries without careful scoping; performance issues from galleries loading thousands of rows without filtering.',
 ARRAY['power-apps','canvas','ui','pl-400'], 'teacher_john', 'teacher_john'),

('concept_pp_appform01', 'App Form Control',
 'power platform',
 'A Canvas or Model-Driven App control for displaying and editing a single Dataverse row, supporting Edit, View, and New modes.',
 'An EditForm bound to the Projects table in Edit mode auto-generates input fields; SubmitForm() writes the changed data back to Dataverse.',
 'An App Form Control is like a pre-printed paper form — the fields are laid out automatically and mapped to the right data fields in the database.',
 'Calling Patch() to save data when a Form control is present — use SubmitForm(); forgetting to call ResetForm() after a successful submit.',
 ARRAY['power-apps','form','dataverse','pl-400'], 'teacher_john', 'teacher_john'),

('concept_pp_custompage01', 'Custom Page',
 'power platform',
 'A Canvas App page embedded inside a Model-Driven App, enabling rich custom UI while retaining access to Dataverse context.',
 'A richly formatted order summary page built in Canvas App style is embedded as a Custom Page inside a Model-Driven App for a seamless UX.',
 'A Custom Page is like inserting a hand-crafted brochure page into a standardized report binder — custom look within a structured container.',
 'Overusing Custom Pages for simple forms that standard MDA forms handle well; Custom Pages require careful navigation and context passing.',
 ARRAY['power-apps','model-driven','canvas','pl-400'], 'teacher_john', 'teacher_john'),

('concept_pp_appdesigner01', 'App Designer',
 'power platform',
 'The visual tool in the Power Apps maker portal for configuring a Model-Driven App''s navigation, forms, views, and dashboards.',
 'In App Designer, a developer adds the Account and Contact tables, selects which views and forms to expose, and sets up the sitemap navigation.',
 'App Designer is like a table of contents editor — it decides which chapters (tables, views, forms) are included and how users navigate between them.',
 'Editing the sitemap directly in XML instead of using App Designer; including too many tables, making the app navigation confusing.',
 ARRAY['power-apps','model-driven','tooling','pl-400'], 'teacher_john', 'teacher_john'),

-- ── Group 4: PCF and Client Scripting ────────────────────────────────────────
('concept_pp_pcf01', 'Power Apps Component Framework (PCF)',
 'power platform',
 'A framework for building reusable code components using TypeScript and standard web technologies that run inside Canvas or Model-Driven Apps.',
 'A custom PCF control renders a colour-coded urgency badge instead of a plain text field on a Model-Driven App form.',
 'PCF is like a browser extension for Power Apps UI — it lets you replace default field renderings with fully custom HTML/CSS/JS controls.',
 'Trying to use PCF to perform data writes outside the control''s bound field; PCF controls are UI-only unless using the Web API from within.',
 ARRAY['pcf','power-apps','typescript','pl-400'], 'teacher_john', 'teacher_john'),

('concept_pp_typescript01', 'TypeScript in PCF',
 'power platform',
 'PCF components are authored in TypeScript; the framework provides a strongly-typed manifest and lifecycle interface (init, updateView, destroy).',
 'The PCF init() method receives the context with the bound field value; updateView() re-renders when the value or app state changes.',
 'The PCF lifecycle (init, updateView, destroy) is like a React component lifecycle (componentDidMount, componentDidUpdate, componentWillUnmount).',
 'Not calling notifyOutputChanged() after user interaction, so the bound field value never updates; missing destroy() cleanup causing memory leaks.',
 ARRAY['pcf','typescript','development','pl-400'], 'teacher_john', 'teacher_john'),

('concept_pp_reactpcf01', 'React Virtual PCF Control',
 'power platform',
 'A PCF control type that renders through a shared React root managed by Power Apps, improving performance by avoiding per-control React instances.',
 'A Virtual PCF control renders a React date-picker component inside the shared Power Apps React root, avoiding duplicate React instances.',
 'A Virtual PCF control is like a sub-component inside a parent React app — it shares the React root rather than spinning up its own isolated tree.',
 'Using Standard (non-virtual) PCF when React is needed, causing multiple conflicting React instances per page.',
 ARRAY['pcf','react','virtual','pl-400'], 'teacher_john', 'teacher_john'),

('concept_pp_pcfmanifest01', 'PCF Manifest',
 'power platform',
 'The ControlManifest.Input.xml file that declares a PCF component''s properties, resources, and feature usage to the Power Apps runtime.',
 'The manifest declares a property "primaryColor" of type SingleLine.Text, which the app maker binds to a Dataverse column or provides a static value.',
 'The PCF manifest is like the spec sheet for a component — it tells Power Apps what inputs the component accepts and what resources it needs.',
 'Forgetting to update the version in the manifest before publishing updated components; property type mismatches causing runtime binding errors.',
 ARRAY['pcf','manifest','configuration','pl-400'], 'teacher_john', 'teacher_john'),

('concept_pp_xrm01', 'Client API (Xrm)',
 'power platform',
 'The JavaScript object model (window.Xrm) available in Model-Driven Apps for manipulating forms, fields, tabs, and navigating records.',
 'formContext.getAttribute("priority").setValue(3) sets the Priority field value; formContext.ui.tabs.get("tab1").setVisible(false) hides a tab.',
 'The Xrm Client API is like the DOM for Model-Driven App forms — it gives JavaScript programmatic access to every form element.',
 'Using document.getElementById() to manipulate form elements instead of the Xrm API — direct DOM access is unsupported and breaks in updates.',
 ARRAY['client-api','xrm','javascript','pl-400'], 'teacher_john', 'teacher_john'),

('concept_pp_formevent01', 'Form Event',
 'power platform',
 'Events fired during the Model-Driven App form lifecycle: OnLoad, OnSave, and OnChange, to which JavaScript handlers can be registered.',
 'An OnLoad handler pre-fills a default Territory field; an OnSave handler validates that a required document is attached before allowing save.',
 'Form events are like hooks in a web framework — they fire at lifecycle points and let you inject custom logic without modifying the platform code.',
 'Performing synchronous HTTP calls inside OnSave without returning a promise, causing the event to complete before the call finishes.',
 ARRAY['client-api','form','events','pl-400'], 'teacher_john', 'teacher_john'),

('concept_pp_fieldevent01', 'Field (Column) Event',
 'power platform',
 'OnChange event on a Model-Driven App form field that fires when a user changes the field value, used for field-level business logic.',
 'An OnChange handler on the Country field filters the Region lookup to show only regions for the selected country.',
 'A field event is like an onChange listener on an HTML input — it fires whenever the user changes the value, allowing reactive field updates.',
 'Triggering infinite loops by programmatically setting a field value inside its own OnChange handler; use fireOnChange: false when setting values in code.',
 ARRAY['client-api','field','events','pl-400'], 'teacher_john', 'teacher_john'),

('concept_pp_jswebres01', 'JavaScript Web Resource',
 'power platform',
 'A .js file stored in Dataverse as a web resource and referenced by form event handlers or ribbon commands in Model-Driven Apps.',
 'A file myapp_formlogic.js registered as a web resource is attached to the Contact form OnLoad event to run business logic on form load.',
 'A JavaScript Web Resource is like a script tag included in a webpage — the file is stored in Dataverse and loaded when the form opens.',
 'Not using a namespace for functions (risk of name collision with other web resources); caching issues after updates requiring a version increment.',
 ARRAY['web-resource','javascript','model-driven','pl-400'], 'teacher_john', 'teacher_john'),

('concept_pp_htmlwebres01', 'HTML Web Resource',
 'power platform',
 'A .html file stored as a Dataverse web resource, embeddable as an iframe inside a Model-Driven App form for fully custom UI.',
 'An HTML web resource displays a custom status timeline iframe inside a form, pulling data from an external service via JavaScript.',
 'An HTML Web Resource embedded in a form is like an iframe pointing to a mini-website hosted inside Dataverse rather than an external server.',
 'Trying to access the parent form''s formContext from inside an HTML web resource iframe — only allowed via the getContentWindow API.',
 ARRAY['web-resource','html','model-driven','pl-400'], 'teacher_john', 'teacher_john'),

('concept_pp_commandbar01', 'Command Bar Customization',
 'power platform',
 'Customizing the ribbon/command bar buttons in Model-Driven Apps using the modern Command Designer or classic Ribbon Workbench.',
 'Adding a custom "Generate PDF" button to the Account form command bar using Command Designer, with a JavaScript action and an enable rule.',
 'Command bar customization is like configuring toolbar buttons in Word — you choose which actions appear and when they are enabled or visible.',
 'Using the legacy Ribbon Workbench when Command Designer supports the use case; forgetting visibility and enable rules causes confusing UX.',
 ARRAY['model-driven','ribbon','command','pl-400'], 'teacher_john', 'teacher_john'),

-- ── Group 5: Power Automate Fundamentals ─────────────────────────────────────
('concept_pp_cloudflow01', 'Cloud Flow',
 'power platform',
 'A Power Automate automation that runs in the cloud, connecting services via triggers and actions without requiring local infrastructure.',
 'A Cloud Flow triggers when a new Dataverse row is created for a Lead, sends a welcome email, and creates a follow-up Task record.',
 'A Cloud Flow is like an automated assembly line — events arrive at one end and are processed through a defined sequence of steps automatically.',
 'Hardcoding environment-specific URLs or IDs inside flow actions instead of using Environment Variables.',
 ARRAY['power-automate','flow','automation','pl-400'], 'teacher_john', 'teacher_john'),

('concept_pp_flowtrigger01', 'Flow Trigger',
 'power platform',
 'The event that starts a Cloud Flow, such as when a Dataverse row is created, a schedule fires, or an HTTP request is received.',
 'A "When a row is added, modified or deleted" Dataverse trigger fires every time a new Opportunity is created with Status = Open.',
 'A trigger is like a motion sensor on a door — it detects that something happened and wakes up the flow to respond.',
 'Using polling triggers (every minute) when event-driven triggers are available, wasting API quota and increasing latency.',
 ARRAY['power-automate','trigger','event','pl-400'], 'teacher_john', 'teacher_john'),

('concept_pp_flowaction01', 'Flow Action',
 'power platform',
 'A unit of work in a Cloud Flow that performs an operation, such as sending an email, updating a Dataverse row, or calling an HTTP endpoint.',
 'A "Send an email (V2)" action sends a notification; a "Get a row by ID" action fetches Dataverse data for use in later steps.',
 'A flow action is like a single step in a recipe — each step does one thing (mix, bake, cool), and steps are chained to complete the dish.',
 'Not configuring retry policies on actions that call external APIs, leading to transient failures causing the entire flow to fail.',
 ARRAY['power-automate','action','step','pl-400'], 'teacher_john', 'teacher_john'),

('concept_pp_condition01', 'Condition',
 'power platform',
 'A Power Automate control action that branches flow execution into "If yes" and "If no" paths based on a boolean expression.',
 'A Condition checks if Priority equals "High"; the "If yes" branch sends a Slack alert; the "If no" branch logs to a SharePoint list.',
 'A Condition is like a road fork with a signpost — depending on which way the condition points, the flow takes the left or right branch.',
 'Nesting many Conditions deeply instead of using a Switch action for multiple discrete values.',
 ARRAY['power-automate','logic','branching','pl-400'], 'teacher_john', 'teacher_john'),

('concept_pp_applytoeach01', 'Apply to Each',
 'power platform',
 'A Power Automate loop control that iterates over each item in an array, executing nested actions for every element.',
 'Apply to Each iterates over a list of new employee emails returned from a query, sending an onboarding email to each one.',
 'Apply to Each is like a for-each loop — for every item in a list, execute the same set of steps with that item as context.',
 'Using Apply to Each when a bulk action is available; nested Apply to Each blocks can cause performance problems.',
 ARRAY['power-automate','loop','array','pl-400'], 'teacher_john', 'teacher_john'),

('concept_pp_errorhandling01', 'Flow Error Handling',
 'power platform',
 'Using Scope actions with "Configure run after" settings (failed, skipped, timed out) to implement try/catch patterns in Cloud Flows.',
 'A Scope action wraps critical steps; a parallel branch with "Configure run after" set to "has failed" sends a Teams alert and logs the error.',
 'Scope with error handling is like a try/catch block in code — the Scope is the try, and the parallel failed-branch is the catch.',
 'Not configuring "Configure run after" on the catch branch, so it only runs on success by default; forgetting to surface the error message for debugging.',
 ARRAY['power-automate','error-handling','resilience','pl-400'], 'teacher_john', 'teacher_john'),

('concept_pp_envvar01', 'Environment Variable',
 'power platform',
 'A solution component that stores configuration values (strings, numbers, JSON, secrets) separately from flow logic, enabling environment-specific settings.',
 'A SharePoint Site URL Environment Variable is set to the DEV site in Development and the PROD site in Production, with no flow edits needed.',
 'An Environment Variable in Power Platform is like a .env file entry — it externalizes configuration so the same logic runs with different settings per environment.',
 'Hardcoding environment-specific values inside flow actions instead of referencing Environment Variables; missing variable values block solution import.',
 ARRAY['power-automate','alm','configuration','pl-400'], 'teacher_john', 'teacher_john'),

('concept_pp_connref01', 'Connection Reference',
 'power platform',
 'A solution component that abstracts the connection used by a connector, allowing credentials to be swapped per environment without editing the flow.',
 'A Connection Reference named "Shared SharePoint Connection" points to different credentials in each environment, set during solution import.',
 'A Connection Reference is like a named database connection string in a config file — the logic refers to the name, and the actual credentials are swapped per environment.',
 'Creating flows without Connection References in a solution, making it impossible to change credentials without editing the flow directly.',
 ARRAY['power-automate','alm','connector','pl-400'], 'teacher_john', 'teacher_john'),

('concept_pp_approval01', 'Approval Flow',
 'power platform',
 'A Power Automate pattern using the Approvals connector to route items for human review, collecting approve/reject responses before continuing.',
 'A flow sends an Approval request to a manager when an expense report exceeds $1000; the flow resumes once the manager approves or rejects in Teams.',
 'An Approval Flow is like a digital signature workflow — work pauses, a human is notified, and the flow resumes only after a person acts.',
 'Not handling the "Reject" outcome and allowing the flow to continue as if approved; approvals time out after 30 days by default.',
 ARRAY['power-automate','approval','human-in-loop','pl-400'], 'teacher_john', 'teacher_john'),

('concept_pp_childflow01', 'Child Flow',
 'power platform',
 'A Cloud Flow called from another flow using the "Run a Child Flow" action, enabling reusable flow logic shared across multiple parent flows.',
 'A "Send Notification" child flow is reused by an onboarding flow, an offboarding flow, and a contract renewal flow, all calling it with different messages.',
 'A child flow is like a function in programming — you write it once with parameters and call it from multiple parent flows instead of duplicating logic.',
 'Creating child flows in the Default Solution, which makes them inaccessible to flows in managed solutions in other environments.',
 ARRAY['power-automate','reuse','modular','pl-400'], 'teacher_john', 'teacher_john'),

-- ── Group 6: Business Process Automation ─────────────────────────────────────
('concept_pp_bpf01', 'Business Process Flow',
 'power platform',
 'A guided, stage-based process overlay in Model-Driven Apps that walks users through required steps to complete a business process.',
 'A "Sales Pipeline" BPF has stages: Qualify → Develop → Propose → Close, each with mandatory fields before the user can advance.',
 'A BPF is like a guided wizard in an application — it walks the user through required steps in order, preventing skipping ahead.',
 'Confusing a BPF stage with a workflow step; BPFs guide human interaction, not automated server-side logic.',
 ARRAY['power-automate','bpf','process','pl-400'], 'teacher_john', 'teacher_john'),

('concept_pp_bpfstage01', 'BPF Stage',
 'power platform',
 'A named phase in a Business Process Flow containing data steps (fields) the user must complete before advancing to the next stage.',
 'The "Develop" stage in a sales BPF requires the user to fill in Budget Amount and Decision Maker before the Next Stage button becomes active.',
 'A BPF Stage is like a level in a video game — you must complete the objectives of the current level to unlock the next.',
 'Adding too many required fields per stage, frustrating users; not testing the BPF behavior when stages are skipped or the record is branched.',
 ARRAY['bpf','stage','process','pl-400'], 'teacher_john', 'teacher_john'),

('concept_pp_bizrule01', 'Business Rule',
 'power platform',
 'A no-code rule configured on a Dataverse table that enforces field requirements, visibility, or default values on forms and server-side.',
 'A business rule makes the Discount field required when Deal Size is "Enterprise" and sets a default 5% value when Deal Size is "SMB".',
 'A Business Rule is like a conditional formatting rule in Excel applied to a form — it shows, hides, or requires fields based on other field values.',
 'Using Business Rules for complex logic that changes data in related tables — they only operate on the current table row and form.',
 ARRAY['dataverse','business-rule','no-code','pl-400'], 'teacher_john', 'teacher_john'),

('concept_pp_custaction01', 'Custom Process Action',
 'power platform',
 'A reusable, named Dataverse operation that can be called from flows, plugins, or client scripts, similar to a lightweight custom API.',
 'A "CalculateDiscount" Custom Process Action takes a Deal ID as input, runs pricing logic, and returns a Discount Percentage as output.',
 'A Custom Process Action is like a named stored procedure — it encapsulates reusable logic callable from flows, plugins, or client scripts by name.',
 'Overusing Custom Process Actions when a simpler Instant Flow or plugin would be more maintainable; they are harder to debug than flows.',
 ARRAY['dataverse','process','reuse','pl-400'], 'teacher_john', 'teacher_john'),

('concept_pp_customapi01', 'Custom API',
 'power platform',
 'A Dataverse extension point that exposes a custom message callable via the Web API, backed by a plugin, with defined request/response parameters.',
 'A "GenerateInvoice" Custom API exposes a message backed by a plugin, callable via POST /api/data/v9.2/GenerateInvoice with JSON parameters.',
 'A Custom API is like defining a new verb for Dataverse — instead of only Create/Update/Delete, you add your own named operation with typed parameters.',
 'Not registering the backing plugin step for the Custom API message; leaving the Custom API without a plugin makes it a no-op that returns nothing.',
 ARRAY['dataverse','api','plugin','pl-400'], 'teacher_john', 'teacher_john'),

('concept_pp_scheduledflow01', 'Scheduled Flow',
 'power platform',
 'A Cloud Flow triggered on a recurring schedule (every X minutes/hours/days), used for batch processing or periodic data synchronization.',
 'A Scheduled Flow runs every day at 2 AM, queries Dataverse for overdue tasks, and sends a daily digest email to each task owner.',
 'A Scheduled Flow is like a cron job — a clock fires it on a fixed schedule rather than waiting for an external event.',
 'Not handling large datasets efficiently in scheduled flows; polling all records without date filters causes unnecessary API usage and timeouts.',
 ARRAY['power-automate','schedule','batch','pl-400'], 'teacher_john', 'teacher_john'),

('concept_pp_automatedflow01', 'Automated Flow',
 'power platform',
 'A Cloud Flow triggered automatically by an event in a connected service, such as a new Dataverse row or an incoming email.',
 'An Automated Flow triggers on "When a new email arrives in a shared mailbox" and creates a Dataverse Case record from the email details.',
 'An Automated Flow is like a reactive event listener — it sits silently and springs into action the moment the watched event occurs.',
 'Triggers firing more than expected due to broad trigger conditions; always add filter conditions to narrow when the flow actually executes.',
 ARRAY['power-automate','automated','event','pl-400'], 'teacher_john', 'teacher_john'),

('concept_pp_instantflow01', 'Instant Flow',
 'power platform',
 'A Cloud Flow triggered manually by a user from the Power Automate app, a Power Apps button, or a Teams message action.',
 'An Instant Flow is triggered by a button in a Canvas App, receives the selected record ID as input, and runs a PDF generation process.',
 'An Instant Flow is like a vending machine button — the user pushes it on demand and the automation runs immediately on request.',
 'Building Instant Flows that depend on context (the selected record) without passing the record ID as an input parameter.',
 ARRAY['power-automate','manual','button','pl-400'], 'teacher_john', 'teacher_john'),

('concept_pp_desktopflow01', 'Desktop Flow (RPA)',
 'power platform',
 'A Power Automate automation that runs on a local machine to automate legacy or desktop applications through UI interaction (Robotic Process Automation).',
 'A Desktop Flow opens a legacy ERP application, reads order data from a screen, and pastes it into a web form — all through UI automation.',
 'A Desktop Flow is like a robot sitting at a computer — it moves the mouse, clicks buttons, and types data just as a human would.',
 'Using Desktop Flows for systems with available APIs — RPA is the last resort when no API exists, as it is fragile to UI changes.',
 ARRAY['power-automate','rpa','desktop','pl-400'], 'teacher_john', 'teacher_john'),

('concept_pp_classicwf01', 'Classic Workflow',
 'power platform',
 'A legacy Dataverse automation (background/real-time process) that predates Power Automate; still supported but recommended to migrate to Cloud Flows.',
 'A classic background workflow runs after an Opportunity is won, automatically creating a follow-up Task and updating the related Account stage.',
 'A Classic Workflow is like a veteran office worker who still uses paper forms — it gets the job done but the modern equivalent (Cloud Flow) is faster and more capable.',
 'Creating new Classic Workflows when Power Automate Cloud Flows cover the same scenario; Workflows lack modern monitoring and cannot be imported into GitHub easily.',
 ARRAY['dataverse','workflow','legacy','pl-400'], 'teacher_john', 'teacher_john'),

-- ── Group 7: Plugin Development ───────────────────────────────────────────────
('concept_pp_plugin01', 'Plugin',
 'power platform',
 'A .NET assembly containing event-handler classes that execute synchronously or asynchronously in response to Dataverse data operations.',
 'A plugin registered on the Create message of the Order table calculates the total price and sets the TotalAmount field before the record is saved.',
 'A plugin is like a database trigger but for Dataverse — it intercepts a data operation and runs custom .NET code before or after it completes.',
 'Writing plugins that call external HTTP services synchronously in Pre-Operation, blocking the user save transaction and causing timeouts.',
 ARRAY['plugin','dataverse','dotnet','pl-400'], 'teacher_john', 'teacher_john'),

('concept_pp_pluginstep01', 'Plugin Step',
 'power platform',
 'The registration of a plugin class against a specific Dataverse message (e.g. Create, Update) and table at a chosen pipeline stage (Pre/Post-Operation).',
 'A Pre-Operation step on Update of the Contact table for attribute filter "Email" runs validation logic only when the Email field changes.',
 'A plugin step registration is like setting up an event listener — you specify exactly which event, table, stage, and attributes trigger the handler.',
 'Not using attribute filtering, causing the plugin to run on every Update regardless of which fields changed, wasting resources.',
 ARRAY['plugin','registration','step','pl-400'], 'teacher_john', 'teacher_john'),

('concept_pp_pluginimage01', 'Plugin Image',
 'power platform',
 'A snapshot of a Dataverse row''s column values captured before (Pre-Image) or after (Post-Image) an operation, available to the plugin for comparison.',
 'A Pre-Image on an Update step captures the old Email value before the update; the plugin compares it to the new value to detect changes.',
 'A plugin image is like a before-and-after photo — the Pre-Image is the "before" snapshot and the Post-Image is the "after" snapshot of the record.',
 'Expecting Pre-Images on Create steps (they do not exist since there is no previous state); Post-Images on Delete steps are also not available.',
 ARRAY['plugin','image','snapshot','pl-400'], 'teacher_john', 'teacher_john'),

('concept_pp_iorgservice01', 'IOrganizationService',
 'power platform',
 'The primary Dataverse service interface in a plugin, used to execute CRUD operations, queries, and custom messages against Dataverse.',
 'service.Create(new Entity("task") { ["subject"] = "Follow up", ["regardingobjectid"] = accountRef }) creates a Task linked to an Account.',
 'IOrganizationService is like the Dataverse SDK client — it is the main handle for all CRUD and message operations inside a plugin or custom code.',
 'Creating a new IOrganizationService inside the plugin instead of obtaining it from IServiceProvider — always use the provided factory to get the service.',
 ARRAY['plugin','service','api','pl-400'], 'teacher_john', 'teacher_john'),

('concept_pp_ipluginctx01', 'IPluginExecutionContext',
 'power platform',
 'The interface providing a plugin with information about the triggering event: input/output parameters, pre/post images, user IDs, and call depth.',
 'context.InputParameters["Target"] retrieves the Entity being created; context.UserId is the user whose action triggered the plugin.',
 'IPluginExecutionContext is like the HTTP request object in a web handler — it carries all the metadata about who triggered the event and what data is involved.',
 'Accessing context.InputParameters without null-checking; assuming the Target is an Entity when it could be an EntityReference for Delete messages.',
 ARRAY['plugin','context','execution','pl-400'], 'teacher_john', 'teacher_john'),

('concept_pp_svccontext01', 'OrganizationServiceContext',
 'power platform',
 'A LINQ-enabled proxy that wraps IOrganizationService, enabling strongly-typed entity queries and change tracking in plugin or custom code.',
 'Using a LINQ query via OrganizationServiceContext: context.AccountSet.Where(a => a.StateCode == AccountState.Active).ToList().',
 'OrganizationServiceContext is like Entity Framework for Dataverse — it wraps the service with LINQ support and identity-mapped object tracking.',
 'Loading large query results with OrganizationServiceContext without paging, causing memory issues; it is less efficient than QueryExpression for bulk reads.',
 ARRAY['plugin','linq','service','pl-400'], 'teacher_john', 'teacher_john'),

('concept_pp_virtualtable01', 'Virtual Table Provider',
 'power platform',
 'A plugin-based provider that maps an external data source into a Dataverse virtual table, enabling CRUD operations on external data via the standard API.',
 'A Virtual Table Provider plugin handles Retrieve and RetrieveMultiple for an ExternalProduct table, fetching live data from a REST API.',
 'A Virtual Table Provider is like a database view backed by an API — Dataverse shows it as a table, but the data actually lives somewhere else.',
 'Expecting filtering, sorting, and paging to work automatically — the provider plugin must manually implement these operations against the external source.',
 ARRAY['plugin','virtual-table','integration','pl-400'], 'teacher_john', 'teacher_john'),

('concept_pp_asyncplugin01', 'Asynchronous Plugin',
 'power platform',
 'A plugin step registered to run asynchronously after the transaction commits via the Async Service, not blocking the synchronous user operation.',
 'A Post-Operation async plugin generates a PDF report after an Invoice is created, running in the background without blocking the user.',
 'An async plugin is like submitting a print job — the user''s action completes immediately, and the long-running task processes in the background.',
 'Using async plugins for logic that must complete before the user sees the result; async plugins run after the transaction and may be delayed.',
 ARRAY['plugin','async','performance','pl-400'], 'teacher_john', 'teacher_john'),

('concept_pp_plugintrace01', 'Plugin Trace Log',
 'power platform',
 'A Dataverse feature that captures ITracingService output from plugins, written to the PluginTraceLog table for debugging failures.',
 'tracingService.Trace("Processing order {0}", order.Id) writes a message viewable in the Plugin Trace Log table after a failure.',
 'Plugin Trace Logs are like server-side console.log for Dataverse plugins — you write messages and read them after the fact to diagnose problems.',
 'Only enabling Plugin Trace Log in Development but forgetting it is off by default in Production, making production failures hard to diagnose.',
 ARRAY['plugin','debugging','trace','pl-400'], 'teacher_john', 'teacher_john'),

('concept_pp_sandbox01', 'Plugin Sandbox Mode',
 'power platform',
 'The isolated execution environment for plugins that restricts access to network, file system, and registry, enforcing security and stability.',
 'A sandboxed plugin cannot open a direct TCP socket or read from the file system; it can only call Dataverse via IOrganizationService or allowed HTTP endpoints.',
 'The plugin sandbox is like a containerized execution environment — it can do its job but cannot reach outside the approved set of system resources.',
 'Attempting file I/O or registry access in plugins, which is blocked by the sandbox and throws SecurityException at runtime.',
 ARRAY['plugin','sandbox','security','pl-400'], 'teacher_john', 'teacher_john'),

-- ── Group 8: Integration and APIs ────────────────────────────────────────────
('concept_pp_webapi01', 'Dataverse Web API',
 'power platform',
 'A RESTful API following the OData v4 standard that provides full CRUD, query, and custom message access to Dataverse data and metadata.',
 'GET /api/data/v9.2/accounts?$select=name,revenue&$filter=statecode eq 0 returns active Account names and revenues as JSON.',
 'The Dataverse Web API is like a universal remote control for your data — any HTTP client (browser, Postman, Python) can read and write Dataverse via standard REST calls.',
 'Not including the required OData-Version and Accept headers; forgetting to handle paging via @odata.nextLink for large result sets.',
 ARRAY['web-api','rest','odata','pl-400'], 'teacher_john', 'teacher_john'),

('concept_pp_odata01', 'OData Query Syntax',
 'power platform',
 'Standard URL query options ($filter, $select, $expand, $orderby, $top) used with the Dataverse Web API to retrieve and shape data.',
 'GET /accounts?$filter=revenue gt 1000000&$select=name,revenue&$top=10&$orderby=revenue desc returns the top 10 richest accounts.',
 'OData query options are like SQL clauses for URLs — $filter is WHERE, $select is SELECT, $orderby is ORDER BY, $top is LIMIT.',
 'Using single quotes incorrectly for GUIDs (use no quotes for Guid in $filter); forgetting $expand for related table columns in the same call.',
 ARRAY['odata','web-api','query','pl-400'], 'teacher_john', 'teacher_john'),

('concept_pp_customconn01', 'Custom Connector',
 'power platform',
 'A user-defined connector built from an OpenAPI definition that wraps any HTTP API for use in Power Apps and Power Automate.',
 'A Custom Connector for a weather API defines operations GetCurrentWeather and GetForecast, then can be used in Canvas Apps and flows like any built-in connector.',
 'A Custom Connector is like writing a driver for a new device — once the driver is written, Power Platform can talk to that API through a familiar interface.',
 'Not specifying authentication in the connector definition, causing every user to need to manually configure credentials; forgetting to test with the connection.',
 ARRAY['connector','custom','openapi','pl-400'], 'teacher_john', 'teacher_john'),

('concept_pp_openapi01', 'OpenAPI Definition',
 'power platform',
 'A machine-readable specification (Swagger/OpenAPI 2.0) that describes an API''s endpoints, parameters, and authentication for custom connectors.',
 'An OpenAPI 2.0 YAML file defines a /customers/{id} GET endpoint with an Authorization Bearer header and a 200 response schema for Custom Connector import.',
 'An OpenAPI definition is like a restaurant menu — it tells you exactly what dishes (endpoints) are available, what ingredients (parameters) you need, and what you get back.',
 'Importing OpenAPI 3.0 specs — Custom Connectors require OpenAPI 2.0 (Swagger); advanced features like callbacks or composition are not supported.',
 ARRAY['openapi','swagger','api','pl-400'], 'teacher_john', 'teacher_john'),

('concept_pp_webhook01', 'Webhook',
 'power platform',
 'A Dataverse service endpoint type that sends an HTTP POST to an external URL when a registered Dataverse event occurs.',
 'A Dataverse webhook sends a POST with the ExecutionContext JSON to an Azure Function URL every time a new Case is created.',
 'A webhook is like a push notification subscription — Dataverse calls your endpoint the moment an event happens, instead of you polling repeatedly.',
 'Not securing the webhook endpoint with a signature or secret; Dataverse webhooks do not retry on failure without additional configuration.',
 ARRAY['webhook','integration','event','pl-400'], 'teacher_john', 'teacher_john'),

('concept_pp_svcendpoint01', 'Service Endpoint',
 'power platform',
 'A Dataverse configuration that routes event messages to Azure Service Bus, Azure Event Hub, or a Webhook target for external integration.',
 'A Service Endpoint configured for an Azure Service Bus queue posts execution context messages for all Opportunity Create events to the bus.',
 'A Service Endpoint is like a post box address for Dataverse events — when an event fires, Dataverse delivers a message to that external address.',
 'Not registering the Service Endpoint in a solution — it will not be transported to other environments during deployment.',
 ARRAY['service-endpoint','azure','integration','pl-400'], 'teacher_john', 'teacher_john'),

('concept_pp_servicebus01', 'Azure Service Bus Integration',
 'power platform',
 'Dataverse can post event context messages to an Azure Service Bus queue or topic, enabling decoupled, async integration with external systems.',
 'A Service Bus-backed Service Endpoint sends order events to a queue; a separate Azure Function consumer processes them and writes to a data warehouse.',
 'Azure Service Bus integration is like a postal service between Dataverse and external systems — Dataverse drops messages in the mailbox and the consumer picks them up at its own pace.',
 'Assuming message ordering is guaranteed in Service Bus queues (it is not by default); use sessions for ordered processing.',
 ARRAY['azure-service-bus','integration','async','pl-400'], 'teacher_john', 'teacher_john'),

('concept_pp_oauth201', 'OAuth 2.0',
 'power platform',
 'The authorization protocol used by Power Platform to authenticate connectors and custom APIs, using client credentials or authorization code flows.',
 'A Custom Connector uses OAuth 2.0 Authorization Code flow; the user signs in once and the connector stores the token for subsequent API calls.',
 'OAuth 2.0 is like a hotel key card system — a central authority (Azure AD) issues a key (token) that grants access to specific rooms (APIs) without sharing your password.',
 'Hardcoding client secrets in connector or flow definitions instead of using Azure Key Vault references or Environment Variables.',
 ARRAY['oauth','security','authentication','pl-400'], 'teacher_john', 'teacher_john'),

('concept_pp_powerbi01', 'Power BI Embedded',
 'power platform',
 'Integration that embeds Power BI reports and dashboards inside Model-Driven App dashboards or forms for in-context analytics.',
 'A Model-Driven App dashboard shows a Power BI report filtered to the current user''s region, providing in-context analytics without leaving the app.',
 'Power BI Embedded in a Model-Driven App is like a live TV screen built into an office wall — the data visualization is part of the workspace, not a separate tool.',
 'Forgetting to configure row-level security (RLS) in Power BI; embedding reports that are not published to the correct Power BI workspace.',
 ARRAY['power-bi','analytics','model-driven','pl-400'], 'teacher_john', 'teacher_john'),

('concept_pp_powerpages01', 'Power Pages',
 'power platform',
 'A low-code platform for building externally-facing websites backed by Dataverse, with built-in authentication and Table Permissions.',
 'A Power Pages portal lets external suppliers log in to view and update their own Dataverse records, with Table Permissions controlling data access.',
 'Power Pages is like a customer-facing storefront window into Dataverse — external users see only what you choose to expose, secured by Table Permissions.',
 'Not setting up Table Permissions before going live; without them all Dataverse data is inaccessible to portal users by default.',
 ARRAY['power-pages','portal','web','pl-400'], 'teacher_john', 'teacher_john'),

-- ── Group 9: ALM and DevOps ───────────────────────────────────────────────────
('concept_pp_alm01', 'Application Lifecycle Management (ALM)',
 'power platform',
 'The practice of managing Power Platform solutions across Development, Test, and Production environments using automated pipelines and source control.',
 'A team maintains a Dev environment for development, a Sandbox for testing, and Production; pipelines automatically export from Dev and import to Sandbox.',
 'Power Platform ALM is like a software deployment pipeline — code (solutions) moves through stages (Dev → Test → Prod) with gates and automation at each step.',
 'Making direct customizations in Production instead of following the Dev → Test → Prod promotion pattern, leading to unmanaged components and drift.',
 ARRAY['alm','devops','deployment','pl-400'], 'teacher_john', 'teacher_john'),

('concept_pp_solchecker01', 'Solution Checker',
 'power platform',
 'A Power Platform tool that performs static analysis of solution components against a ruleset to identify performance, reliability, and upgrade issues.',
 'Running Solution Checker before release flags a plugin that calls an external URL synchronously in Pre-Operation as a high severity issue.',
 'Solution Checker is like a linter or SonarQube scan for Power Platform — it finds code smells, anti-patterns, and compliance violations before deployment.',
 'Ignoring Solution Checker warnings as optional — many issues it flags will cause failures in Managed Environments where enforcement is mandatory.',
 ARRAY['alm','quality','static-analysis','pl-400'], 'teacher_john', 'teacher_john'),

('concept_pp_ppcli01', 'Power Platform CLI (pac)',
 'power platform',
 'A cross-platform command-line tool for automating Power Platform tasks: exporting/importing solutions, managing environments, and scaffolding PCF projects.',
 'pac solution export --name MySolution --path ./solutions exports a solution zip; pac solution import --path ./solutions/MySolution.zip imports it.',
 'The pac CLI is like git for Power Platform solutions — it gives developers a command-line interface to manage environments and solutions in scripts and pipelines.',
 'Not authenticating with pac auth create before running commands; running pac commands outside the correct directory context.',
 ARRAY['cli','devops','pac','pl-400'], 'teacher_john', 'teacher_john'),

('concept_pp_azdevops01', 'Azure DevOps for Power Platform',
 'power platform',
 'Using Azure DevOps pipelines with the Power Platform Build Tools extension to automate solution export, check, import, and release across environments.',
 'A YAML pipeline uses the "Power Platform Export Solution" task to pull the solution from Dev, commits it to Git, then deploys to Test.',
 'Azure DevOps pipelines for Power Platform are like a factory conveyor belt — the solution enters one end in Dev and emerges packaged and tested in Production.',
 'Not storing service principal credentials securely in Azure DevOps variable groups (marked as secret); running pipelines as a named user instead of a service principal.',
 ARRAY['azure-devops','alm','pipeline','pl-400'], 'teacher_john', 'teacher_john'),

('concept_pp_ghactions01', 'GitHub Actions for Power Platform',
 'power platform',
 'A set of GitHub Actions (microsoft/powerplatform-actions) that automate solution packaging, publishing, and environment management in GitHub CI/CD workflows.',
 'A GitHub Actions workflow uses microsoft/powerplatform-actions/export-solution@v1 to export on push to main and microsoft/powerplatform-actions/import-solution@v1 to deploy.',
 'GitHub Actions for Power Platform is like a CI/CD pipeline that treats Power Platform solutions the same as code — with automated build, test, and deploy steps.',
 'Storing environment URLs and credentials directly in the workflow YAML file instead of using GitHub Secrets and Variables.',
 ARRAY['github-actions','alm','ci-cd','pl-400'], 'teacher_john', 'teacher_john'),

('concept_pp_envstrategy01', 'Environment Strategy',
 'power platform',
 'Planning and structuring Power Platform environments (Development, Sandbox, UAT, Production) to support team collaboration and safe deployments.',
 'Small team: Developer Sandbox → Shared Test → Production. Enterprise: Individual Dev → Integration → UAT → Pre-prod → Production.',
 'An environment strategy is like lanes in a swimming pool — each lane has a purpose (practice, warm-up, race), and mixing them causes chaos.',
 'Having only one environment and making changes directly in Production; not documenting which environments require managed solutions.',
 ARRAY['environment','alm','governance','pl-400'], 'teacher_john', 'teacher_john'),

('concept_pp_managedenv01', 'Managed Environment',
 'power platform',
 'A premium Power Platform feature enabling enhanced governance: weekly digest, usage insights, solution checker enforcement, and sharing limits.',
 'Managed Environment is enabled on Production; makers receive a weekly digest of unused apps, and Solution Checker is automatically enforced on imports.',
 'A Managed Environment is like a city with zoning laws — extra guardrails that automatically enforce policies and provide visibility beyond a standard environment.',
 'Enabling Managed Environments without reviewing the sharing limits and Solution Checker rules that will be automatically enforced.',
 ARRAY['environment','governance','admin','pl-400'], 'teacher_john', 'teacher_john'),

('concept_pp_sollayers01', 'Solution Layers',
 'power platform',
 'The stacked customization model in Dataverse where each solution adds a layer on top of base components; the active layer is the merged result.',
 'An ISV installs a managed solution; a customer adds an unmanaged customization on top. Viewing the Account form shows two layers: the ISV base and the customer override.',
 'Solution layers are like CSS specificity — multiple rules can target the same element, and the most specific (top layer) wins.',
 'Customizing managed solution components without understanding that removing the customization layer reverts to the ISV default, not deletes the component.',
 ARRAY['solution','layers','customization','pl-400'], 'teacher_john', 'teacher_john'),

('concept_pp_depcheck01', 'Dependency Checker',
 'power platform',
 'A Dataverse tool that identifies components that depend on or are required by a given solution component, preventing accidental deletion.',
 'Dependency Checker shows that removing the Priority column will break a Cloud Flow, a Business Rule, and a Plugin Step that all reference it.',
 'The Dependency Checker is like a "what uses this" feature in an IDE — before deleting a component, you see all the places that depend on it.',
 'Deleting components without running Dependency Checker first; this causes broken references that are difficult to diagnose after the fact.',
 ARRAY['solution','dependency','alm','pl-400'], 'teacher_john', 'teacher_john'),

('concept_pp_fieldsecp01', 'Field Security Profile',
 'power platform',
 'A Dataverse security construct that restricts which users or teams can read, create, or update specific sensitive columns on a table.',
 'A "Finance Only" Field Security Profile grants Read/Update on the Salary column to users in the Finance team and denies access to all others.',
 'A Field Security Profile is like column-level access control in a database — even if you can see the table, certain columns require an extra key.',
 'Confusing Field Security Profiles with regular security role column access; FSPs are additive — you must explicitly grant access to each team.',
 ARRAY['security','field','dataverse','pl-400'], 'teacher_john', 'teacher_john'),

-- ── Group 10: Security and Governance ────────────────────────────────────────
('concept_pp_dlp01', 'Data Loss Prevention (DLP) Policy',
 'power platform',
 'An admin-configured policy that classifies connectors into Business, Non-Business, or Blocked tiers to prevent unauthorized data exfiltration in flows.',
 'A DLP policy places SharePoint and Dataverse in the Business tier and Dropbox in Non-Business, blocking flows that combine both tiers.',
 'A DLP policy is like a building security checkpoint — it blocks certain combinations of services from passing data between each other without approval.',
 'Creating overly restrictive DLP policies that block legitimate business flows; test DLP policies in a sandbox before applying to Production.',
 ARRAY['dlp','governance','security','pl-400'], 'teacher_john', 'teacher_john'),

('concept_pp_admincenter01', 'Power Platform Admin Center',
 'power platform',
 'The web portal for managing environments, capacity, DLP policies, connectors, and tenant-level analytics across the Power Platform tenant.',
 'In Admin Center, an admin creates a new sandbox environment, applies a DLP policy, and monitors storage capacity across all environments.',
 'The Admin Center is like a control room for the entire Power Platform — all environments, policies, and tenant-level settings are managed from one place.',
 'Granting Power Platform Admin role broadly; use Environment Admin for environment-specific management and reserve tenant admin for tenant-wide policies.',
 ARRAY['admin','governance','portal','pl-400'], 'teacher_john', 'teacher_john'),

('concept_pp_coe01', 'Center of Excellence (CoE) Toolkit',
 'power platform',
 'A reference implementation of governance tooling deployed to a Power Platform environment to gain visibility, drive adoption, and enforce standards.',
 'After deploying the CoE Toolkit, admins see a Power BI dashboard showing all Canvas Apps, Flows, and Connectors in use across the tenant.',
 'The CoE Toolkit is like a governance dashboard for a city government — it gives leaders visibility into what is being built and by whom, so they can guide and govern effectively.',
 'Treating the CoE Toolkit as a finished product — it is a reference implementation that requires customization and ongoing maintenance.',
 ARRAY['coe','governance','toolkit','pl-400'], 'teacher_john', 'teacher_john'),

('concept_pp_tenantanalytics01', 'Tenant-level Analytics',
 'power platform',
 'Admin Center reports showing usage metrics across all environments: active users, flow runs, connector usage, and app launches at the tenant level.',
 'Tenant Analytics shows that 80% of active Cloud Flows in Production belong to three users, flagging a key-person dependency risk.',
 'Tenant Analytics is like a fitness tracker for your Power Platform tenant — it shows activity, usage patterns, and areas that need attention.',
 'Not reviewing analytics regularly; tenant analytics data has a lag (up to 28 days) and should not be used for real-time monitoring.',
 ARRAY['analytics','governance','admin','pl-400'], 'teacher_john', 'teacher_john'),

('concept_pp_managedid01', 'Managed Identity Authentication',
 'power platform',
 'Using Azure-managed identities (system-assigned or user-assigned) for Power Platform connectors and Azure resources to avoid storing credentials.',
 'An Azure Function triggered by Dataverse uses a system-assigned managed identity to authenticate to Azure Key Vault without any stored secrets.',
 'A managed identity is like an employee badge issued by the building (Azure) itself — the employee (service) does not need to carry a separate key (password).',
 'Using client secrets in connection strings when managed identities are available; secrets expire and rotate, managed identities are automatic.',
 ARRAY['security','managed-identity','azure','pl-400'], 'teacher_john', 'teacher_john'),

('concept_pp_apilimit01', 'API Request Limits',
 'power platform',
 'Per-user, per-day limits on Dataverse and connector API calls in Power Platform, with capacity add-ons available for high-volume workloads.',
 'A user with a per-user license gets 40,000 API requests per day; a flow that processes 50,000 rows daily requires a capacity add-on.',
 'API request limits are like a data plan on a phone — you get an allocation per period, and if you exceed it, performance is throttled or blocked.',
 'Not monitoring API consumption until throttling occurs in Production; building high-volume integrations without checking if capacity add-ons are needed.',
 ARRAY['licensing','limits','capacity','pl-400'], 'teacher_john', 'teacher_john'),

('concept_pp_licensing01', 'Power Platform Licensing',
 'power platform',
 'The licensing model covering per-app, per-user, and pay-as-you-go plans for Power Apps, plus premium connector and Dataverse capacity entitlements.',
 'A user with a Power Apps per-user plan can use all premium connectors and Dataverse; a user with Microsoft 365 only cannot use premium features.',
 'Power Platform licensing is like a tiered streaming service — the free tier gives basic features, the premium tier unlocks everything, and you pay per user or per app.',
 'Assuming Microsoft 365 licenses cover premium connectors or Dataverse; missing that Power Apps per-app licenses are per-app per-user, not per-tenant.',
 ARRAY['licensing','admin','governance','pl-400'], 'teacher_john', 'teacher_john'),

('concept_pp_dvteam01', 'Dataverse Team',
 'power platform',
 'A group of users in Dataverse (Owner, Access, or AAD Group team) that can be assigned security roles, simplifying bulk permission management.',
 'An "EMEA Sales" AAD Group Team is assigned the Sales Rep security role; all Azure AD group members automatically inherit the role in Dataverse.',
 'A Dataverse Team is like a user group in Active Directory mapped to Dataverse permissions — manage the group membership and the Dataverse access follows.',
 'Assigning security roles directly to individual users when teams should be used; direct assignments are harder to audit and maintain at scale.',
 ARRAY['security','team','dataverse','pl-400'], 'teacher_john', 'teacher_john'),

('concept_pp_hierarchysec01', 'Hierarchy Security',
 'power platform',
 'A Dataverse security model (Manager or Position hierarchy) that grants managers read or write access to their direct and indirect reports'' records.',
 'With Manager Hierarchy enabled, a regional manager can read all records owned by their direct reports even if the records are in a different BU.',
 'Hierarchy Security is like a reporting chain in an org chart — managers automatically get visibility into their reports'' work without explicit sharing.',
 'Enabling Hierarchy Security without setting the correct manager field on users; without the parent relationship set, the hierarchy model has no effect.',
 ARRAY['security','hierarchy','dataverse','pl-400'], 'teacher_john', 'teacher_john'),

('concept_pp_pad01', 'Power Automate Desktop (PAD)',
 'power platform',
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
-- Business Value — 146 concepts across 8 topics
-- =============================================================================

-- ---------------------------------------------------------------------------
-- Folder
-- ---------------------------------------------------------------------------

INSERT INTO folders (id, folder_type, owner_id, is_locked, name, description, domain, theme, icon, created_by, updated_by)
VALUES
    ('folder_pl900_01',
     'teacher', 'teacher_john', false,
     'Microsoft Certified: Power Platform Fundamentals (PL-900)',
     'Business value study material for the PL-900 exam: Power Platform overview, foundational components, Power Apps, Power Automate, Power BI, Power Pages, Power Virtual Agents / Copilot Studio, and Microsoft Cloud integration.',
     'power platform', 'blue', 'star',
     'teacher_john', 'teacher_john')
ON CONFLICT (id) DO NOTHING;

INSERT INTO folder_members (folder_id, user_id, role, added_by)
VALUES
    ('folder_pl900_01', 'learner_alex', 'viewer', 'teacher_john'),
    ('folder_pl900_01', 'learner_mia',  'viewer', 'teacher_john')
ON CONFLICT (folder_id, user_id) DO NOTHING;

-- ---------------------------------------------------------------------------
-- 146 Concepts
-- ---------------------------------------------------------------------------

INSERT INTO concepts (id, canonical_name, domain, description, example,
analogy, common_mistakes, tags, created_by, updated_by)
VALUES

-- ── Group 1: Power Platform Overview & Business Value ────────────────────────
('concept_pl9_pp01', 'Microsoft Power Platform',
 'power platform',
 'A suite of low-code tools — Power Apps, Power Automate, Power BI, and Copilot Studio — that enables organisations to analyse data, build apps, automate processes, and create chatbots.',
 'A retail company uses Power BI to track sales, Power Apps for store audits, and Power Automate to send restock alerts — all without writing traditional code.',
 'Power Platform is like a Swiss Army knife for business problems — a set of purpose-built tools that work individually but are most powerful when used together.',
 'Thinking Power Platform replaces enterprise development entirely; it complements pro-code work but is not suited for every complex, high-scale scenario.',
 ARRAY['power-platform','overview','pl-900'], 'teacher_john', 'teacher_john'),

('concept_pl9_lowcode01', 'Low-Code / No-Code Development',
 'power platform',
 'An approach to building applications and automations using visual designers and configuration rather than hand-written code, dramatically lowering the skill barrier.',
 'A HR manager builds a leave-request app in Power Apps using drag-and-drop in an afternoon — no developer needed.',
 'Low-code development is like flat-pack furniture — the components are pre-engineered, and you assemble them visually rather than crafting each piece from raw materials.',
 'Assuming low-code means no governance or best practices; low-code apps still need security, ALM, and testing just like traditional software.',
 ARRAY['low-code','citizen-dev','pl-900'], 'teacher_john', 'teacher_john'),

('concept_pl9_citizendev01', 'Citizen Developer',
 'power platform',
 'A business user who builds apps or automations using low-code tools without a traditional software development background, empowered by platforms like Power Platform.',
 'A finance analyst builds a Power Apps expense-approval tool and a Power Automate flow to route approvals — without IT involvement.',
 'A citizen developer is like a self-taught home cook — not a professional chef, but capable of producing great results with the right kitchen tools and recipes.',
 'Citizen developers operating without guardrails (DLP, governance) can create shadow IT, security risks, and unsupported apps that break when the maker leaves.',
 ARRAY['citizen-dev','low-code','governance','pl-900'], 'teacher_john', 'teacher_john'),

('concept_pl9_digitaltx01', 'Digital Transformation',
 'power platform',
 'The process of using digital technology to fundamentally change how an organisation operates and delivers value, replacing manual or paper-based processes.',
 'A logistics company replaces paper delivery forms with a Power Apps mobile app and automatically updates Dataverse records in real time.',
 'Digital transformation is like replacing a paper filing cabinet with a searchable cloud database — the goal is the same but the speed, accuracy, and accessibility are transformed.',
 'Treating digital transformation as purely a technology project; it requires process redesign, change management, and leadership buy-in to succeed.',
 ARRAY['digital-transformation','business-value','pl-900'], 'teacher_john', 'teacher_john'),

('concept_pl9_dataverse_bv01', 'Dataverse Business Value',
 'power platform',
 'Dataverse provides a secure, scalable, standards-based data store shared across Power Platform apps, reducing data silos and enabling consistent business logic.',
 'A company stores customer data once in Dataverse and uses it across a Canvas App for sales reps, a Model-Driven App for support, and a Power BI report for managers.',
 'Dataverse is like a single source of truth for your organisation — instead of data scattered across spreadsheets and siloed apps, everything connects to one governed store.',
 'Confusing Dataverse with a simple database; its business value lies in built-in security, audit, API, and integration with the entire Power Platform ecosystem.',
 ARRAY['dataverse','data','pl-900'], 'teacher_john', 'teacher_john'),

('concept_pl9_environment01', 'Power Platform Environment',
 'power platform',
 'A container that holds Power Platform apps, flows, and Dataverse data, used to separate Development, Test, and Production workloads and control access.',
 'An organisation has a Dev environment for makers to experiment, a Test environment for UAT, and a Production environment that business users access daily.',
 'An environment is like a separate office floor — the same company (tenant) owns all floors, but each floor has its own apps, data, and access rules.',
 'Doing all work in the Default environment; it is shared across the entire tenant and has no isolation, making governance impossible.',
 ARRAY['environment','governance','pl-900'], 'teacher_john', 'teacher_john'),

('concept_pl9_m365int01', 'Microsoft 365 Integration',
 'power platform',
 'Power Platform integrates natively with Microsoft 365 services (Teams, SharePoint, Outlook, Excel) enabling apps and automations to extend familiar workplace tools.',
 'A Power Automate flow triggers when a new file is added to SharePoint, extracts data using AI Builder, and posts a summary to a Teams channel.',
 'M365 integration is like having Power Platform built into your existing office tools — you do not replace Teams or SharePoint, you extend them with apps and automation.',
 'Building standalone Power Apps when embedding them inside Teams or SharePoint would give users a more seamless, adoption-friendly experience.',
 ARRAY['microsoft-365','integration','pl-900'], 'teacher_john', 'teacher_john'),

('concept_pl9_azureint01', 'Azure Integration',
 'power platform',
 'Power Platform connects to Azure services (Azure SQL, Functions, Service Bus, Cognitive Services) enabling enterprise-grade capabilities within low-code solutions.',
 'A Canvas App connects to an Azure SQL database via a custom connector; a flow calls an Azure Function for heavy computation and returns the result.',
 'Azure integration is like a low-code app with a powerful engine under the hood — the Power Platform frontend is accessible to makers, while Azure handles the heavy lifting.',
 'Thinking Power Platform and Azure are competing alternatives; they are complementary — Power Platform for rapid development, Azure for complex back-end services.',
 ARRAY['azure','integration','pl-900'], 'teacher_john', 'teacher_john'),

('concept_pl9_d365int01', 'Dynamics 365 Integration',
 'power platform',
 'Power Platform extends Dynamics 365 CRM and ERP applications by adding custom apps, automations, and dashboards built on the shared Dataverse data layer.',
 'A sales team uses Dynamics 365 Sales for CRM; a maker adds a custom Canvas App for a simplified mobile view and a Power Automate flow for deal notifications.',
 'Dynamics 365 and Power Platform are like a smartphone and its app store — Dynamics 365 is the built-in platform, and Power Platform lets you build tailored extensions on top.',
 'Assuming Power Platform replaces Dynamics 365; they share the same Dataverse foundation and are designed to work together, not as alternatives.',
 ARRAY['dynamics-365','integration','pl-900'], 'teacher_john', 'teacher_john'),

('concept_pl9_tco01', 'Total Cost of Ownership (TCO)',
 'power platform',
 'The full cost of a technology solution including licences, development, maintenance, and training; Power Platform typically reduces TCO vs. custom-coded alternatives.',
 'A company estimates a custom app would cost £200k to build and £50k/year to maintain; the same solution on Power Platform costs £20k to build and £10k/year.',
 'TCO is like comparing the true cost of owning two cars — one cheaper to buy but expensive to service, one slightly pricier upfront but cheap to run long-term.',
 'Focusing only on licence cost while ignoring maker training, governance overhead, and support costs when calculating TCO for Power Platform.',
 ARRAY['tco','business-value','licensing','pl-900'], 'teacher_john', 'teacher_john'),

-- ── Group 1B: Foundational Components ────────────────────────────────────────
('concept_pl9_found_dataverse01', 'Dataverse as a Foundation',
 'power platform',
 'Microsoft Dataverse is the foundational data platform for Power Platform, providing secure storage, relationships, business logic, and integration for apps, flows, analytics, and portals.',
 'An organisation stores customer, case, and booking data in Dataverse once and then uses the same records in Power Apps, Power Automate, Power BI, and Power Pages.',
 'Dataverse is like the central warehouse for the whole platform — every connected tool can draw from the same organised stock.',
 'Thinking Dataverse is only for developers or only for CRM scenarios; in PL-900 it is a core shared foundation for many low-code solutions.',
 ARRAY['dataverse','foundation','power-platform','pl-900'], 'teacher_john', 'teacher_john'),

('concept_pl9_found_tables01', 'Tables and Columns',
 'power platform',
 'Tables organise business data into records and columns, forming the core structure used by Dataverse-backed apps, flows, and reports.',
 'A service-management solution uses an Incident table with columns for Priority, Status, Assigned Technician, and Reported Date.',
 'Tables and columns are like labelled drawers and folders in a filing cabinet — each drawer groups one kind of information and each folder slot stores one property.',
 'Designing tables around spreadsheet habits instead of clear business entities, leading to duplicated fields and confusing data structures.',
 ARRAY['dataverse','tables','columns','pl-900'], 'teacher_john', 'teacher_john'),

('concept_pl9_found_relationships01', 'Relationships Between Tables',
 'power platform',
 'Relationships connect Dataverse tables so related records can work together, such as one customer having many orders or one case belonging to one account.',
 'A university links Student records to Course Enrolment records so one student can have many enrolments while each enrolment belongs to one student.',
 'Relationships are like lines on an org chart or family tree — they show how separate records are connected and how information flows between them.',
 'Keeping everything in one oversized table instead of modelling relationships properly, which makes the data harder to maintain and report on.',
 ARRAY['dataverse','relationships','data-model','pl-900'], 'teacher_john', 'teacher_john'),

('concept_pl9_found_choices01', 'Choice Columns',
 'power platform',
 'Choice columns store standardised options such as status, priority, or department so users select from controlled values instead of typing free text.',
 'A Helpdesk table uses a Priority choice with Low, Medium, High, and Critical to keep reporting consistent across all tickets.',
 'Choice columns are like a set menu instead of an open text box — everyone picks from the same options, so the data stays clean.',
 'Using plain text for values that should be standardised, which leads to inconsistent entries like "High", "high", and "urgent".',
 ARRAY['dataverse','choice','standardisation','pl-900'], 'teacher_john', 'teacher_john'),

('concept_pl9_found_businessrules01', 'Business Rules',
 'power platform',
 'Business rules apply simple logic such as required fields, recommendations, and conditional visibility without needing custom code.',
 'A business rule makes Resolution Date required only when a support case status is changed to Closed.',
 'Business rules are like office policy signs posted at the point of work — they guide behaviour and enforce simple standards automatically.',
 'Trying to use business rules for complex multi-system automation when they are better suited to lightweight form and data logic.',
 ARRAY['dataverse','business-rules','logic','pl-900'], 'teacher_john', 'teacher_john'),

('concept_pl9_found_securityroles01', 'Security Roles',
 'power platform',
 'Security roles determine what users can read, create, update, or delete in Dataverse so different jobs see and manage only the right data.',
 'A customer-service role can update cases and contacts, while an executive role can read dashboards and reports without editing operational records.',
 'Security roles are like job-specific access badges — each badge opens only the rooms needed for that role.',
 'Giving broad admin-level access because it is faster during setup, which creates unnecessary risk and weakens governance.',
 ARRAY['security','roles','dataverse','pl-900'], 'teacher_john', 'teacher_john'),

('concept_pl9_found_connectors01', 'Connectors',
 'power platform',
 'Connectors are the reusable integration components that let Power Platform talk to services such as SharePoint, Outlook, Teams, SQL Server, Salesforce, and hundreds of others.',
 'A solution uses the Outlook connector to send emails, the Teams connector to post notifications, and the SharePoint connector to store documents.',
 'Connectors are like universal plugs that let Power Platform tools connect to many different systems without custom wiring each time.',
 'Assuming all connectors are equal in licensing, capability, or governance impact; connector choice affects security, cost, and maintainability.',
 ARRAY['connectors','integration','power-platform','pl-900'], 'teacher_john', 'teacher_john'),

('concept_pl9_found_customconnectors01', 'Custom Connectors',
 'power platform',
 'Custom connectors package an organisation''s own API or a niche external service so makers can reuse it in apps and flows like any other connector.',
 'A logistics company wraps its internal shipment-tracking API in a custom connector so both Power Apps and Power Automate can use the same endpoints.',
 'A custom connector is like creating your own power adapter for a device that does not come with a standard plug.',
 'Building duplicate HTTP calls in many flows when a reusable custom connector would make the integration easier to govern and maintain.',
 ARRAY['custom-connector','integration','api','pl-900'], 'teacher_john', 'teacher_john'),

('concept_pl9_found_powerfx01', 'Power Fx',
 'power platform',
 'Power Fx is the low-code formula language used in Power Platform to define behaviour, calculations, filtering, and logic in apps and other experiences.',
 'A canvas app uses Filter() to show only open tasks assigned to the current user and uses If() to highlight overdue records.',
 'Power Fx is like the spreadsheet formula language for the whole low-code platform — familiar functions drive smart behaviour without full application code.',
 'Treating Power Fx like a traditional programming language and overcomplicating formulas instead of keeping expressions readable and modular.',
 ARRAY['power-fx','formula','logic','pl-900'], 'teacher_john', 'teacher_john'),

('concept_pl9_found_canvas01', 'Canvas Apps',
 'power platform',
 'Canvas Apps give makers full control over the user interface, making them suitable when the experience must be tailored to a specific process, device, or audience.',
 'A field inspection app is designed as a mobile-first canvas app with large buttons, photo capture, and offline support for technicians in the field.',
 'Canvas Apps are like designing a custom poster from a blank page — you choose where every element goes and how users interact with it.',
 'Using a canvas app for every scenario by default; some data-centric business processes are faster to deliver with model-driven apps.',
 ARRAY['power-apps','canvas-app','ui','pl-900'], 'teacher_john', 'teacher_john'),

('concept_pl9_found_modeldriven01', 'Model-Driven Apps',
 'power platform',
 'Model-driven apps generate much of the user experience from Dataverse structure, making them strong for process-heavy, data-centric business solutions.',
 'A case-management app uses model-driven forms, views, and dashboards so staff can work across large sets of records with minimal custom UI design.',
 'Model-driven apps are like furnishing a building from an architectural plan — once the structure is right, much of the layout comes automatically.',
 'Judging model-driven apps by the same design criteria as canvas apps; their strength is consistency and speed around complex data processes, not pixel-perfect layout control.',
 ARRAY['power-apps','model-driven','dataverse','pl-900'], 'teacher_john', 'teacher_john'),

('concept_pl9_found_cloudflows01', 'Cloud Flows as a Component',
 'power platform',
 'Cloud Flows are a core automation component in Power Platform, used to connect systems, react to events, and move information through business processes.',
 'A cloud flow starts when a new support ticket is created, sends an acknowledgement email, creates a Teams notification, and updates a tracking list.',
 'Cloud Flows are like the conveyor belts between systems — once triggered, they carry work from one step to the next automatically.',
 'Thinking flows are only about sending emails; in practice they are a foundational orchestration tool across the platform.',
 ARRAY['power-automate','cloud-flow','foundation','pl-900'], 'teacher_john', 'teacher_john'),

('concept_pl9_found_desktopflows01', 'Desktop Flows as a Component',
 'power platform',
 'Desktop Flows extend Power Platform to legacy desktop and on-premises software by automating user-interface interactions where APIs are unavailable.',
 'A finance team uses a desktop flow to extract month-end data from a legacy accounting package and load it into a modern reporting process.',
 'Desktop Flows are like robotic hands operating an old machine that cannot be integrated any other way.',
 'Using desktop automation for systems that already expose stable APIs, where a cloud-based integration would usually be more reliable.',
 ARRAY['power-automate','desktop-flow','rpa','pl-900'], 'teacher_john', 'teacher_john'),

('concept_pl9_found_reports01', 'Reports as a Foundational Insight Component',
 'power platform',
 'Power BI reports are a foundational analytics component that turns shared business data into interactive analysis for operational and strategic decision-making.',
 'An operations manager opens a report to compare service volumes, resolution times, and backlog by region and drill into underperforming teams.',
 'Reports are like interactive briefing packs — they present the facts and let the reader investigate the story behind them.',
 'Seeing reports as optional decoration instead of a core part of how business users understand and act on Power Platform data.',
 ARRAY['power-bi','reports','analytics','pl-900'], 'teacher_john', 'teacher_john'),

('concept_pl9_found_dashboards01', 'Dashboards as a Monitoring Component',
 'power platform',
 'Dashboards provide at-a-glance visibility into important metrics and are often the first place leaders look to monitor business health.',
 'An executive dashboard shows revenue, backlog, customer satisfaction, and open risks from multiple underlying reports in one place.',
 'Dashboards are like the instrument panel in a vehicle — they surface the indicators you need to watch continuously.',
 'Trying to make dashboards answer every detailed question; they are best used for overview and alerting, with deeper analysis left to reports.',
 ARRAY['power-bi','dashboard','monitoring','pl-900'], 'teacher_john', 'teacher_john'),

('concept_pl9_found_pagesites01', 'Power Pages Sites',
 'power platform',
 'Power Pages is the foundational website component for securely exposing selected business processes and data to external users such as customers, partners, or citizens.',
 'A local authority publishes a permit portal where residents submit requests and track status without staff emailing PDFs back and forth.',
 'Power Pages sites are like controlled storefronts for your business data — the public sees only the services and information intentionally exposed.',
 'Treating a Power Pages site as if it were just another internal app screen; portal security and external user design require a different mindset.',
 ARRAY['power-pages','portal','external-users','pl-900'], 'teacher_john', 'teacher_john'),

('concept_pl9_found_copilotstudio01', 'Copilot Studio Bots',
 'power platform',
 'Copilot Studio is the conversational component of Power Platform, letting organisations create bots and copilots that answer questions and trigger actions.',
 'A staff-support bot answers policy questions, creates IT tickets, and escalates unresolved issues to a human service desk.',
 'Copilot Studio bots are like digital receptionists who can speak, guide, and hand work off to back-office processes.',
 'Assuming bots replace every service interaction; they work best for repeatable, high-volume queries and well-defined tasks.',
 ARRAY['copilot-studio','bot','conversation','pl-900'], 'teacher_john', 'teacher_john'),

('concept_pl9_found_aibuilder01', 'AI Builder Models',
 'power platform',
 'AI Builder brings ready-to-use and custom AI capabilities into Power Platform so makers can classify, predict, detect, and extract information without becoming machine-learning specialists.',
 'A flow uses AI Builder to extract key fields from invoices and route them into an approval process.',
 'AI Builder is like adding a smart scanner and pattern recogniser to your low-code toolkit.',
 'Expecting AI Builder to be magically accurate in every scenario without training data, testing, and ongoing refinement.',
 ARRAY['ai-builder','ai','low-code','pl-900'], 'teacher_john', 'teacher_john'),

('concept_pl9_found_environmentstrategy01', 'Environment Strategy Basics',
 'power platform',
 'An environment strategy defines how Dev, Test, and Production are separated so solutions can be built safely, validated properly, and released with control.',
 'A council uses a development environment for experiments, a test environment for user acceptance, and a locked production environment for live services.',
 'Environment strategy is like using separate kitchens for recipe testing and restaurant service — you do not experiment in the room serving customers.',
 'Keeping all makers and all workloads in one shared environment, which increases risk and makes governance harder.',
 ARRAY['environment','strategy','governance','pl-900'], 'teacher_john', 'teacher_john'),

('concept_pl9_found_defaultenv01', 'Default Environment',
 'power platform',
 'The default environment is the tenant''s shared starting space, but relying on it for important business solutions usually creates governance and lifecycle-management problems.',
 'A company discovers dozens of abandoned apps and flows in the default environment because makers built there without a managed environment strategy.',
 'The default environment is like the shared office lobby — useful for entry, but not the best place to run every important operation.',
 'Assuming the default environment is the right long-term home for production solutions just because it already exists.',
 ARRAY['default-environment','governance','power-platform','pl-900'], 'teacher_john', 'teacher_john'),

('concept_pl9_found_solutions01', 'Solutions',
 'power platform',
 'Solutions package apps, flows, tables, and other components together so they can be managed, moved, and governed across environments.',
 'A customer-service solution includes a model-driven app, automated flows, Dataverse tables, and security components deployed together to production.',
 'A solution is like a labelled moving crate — all the related pieces of a system travel together instead of being carried one by one.',
 'Creating components directly in the default workspace without using solutions, which makes release management and reuse much harder.',
 ARRAY['solutions','alm','power-platform','pl-900'], 'teacher_john', 'teacher_john'),

('concept_pl9_found_managed01', 'Managed vs Unmanaged Solutions',
 'power platform',
 'Unmanaged solutions are used during development, while managed solutions are controlled release packages intended for downstream environments such as test and production.',
 'A team develops in an unmanaged solution in Dev, then deploys a managed version into Production so users cannot accidentally alter shipped components.',
 'Managed vs unmanaged is like source files versus packaged software — one is built for editing, the other for controlled use.',
 'Importing unmanaged customisations into production because it feels faster, which weakens governance and makes updates harder to control.',
 ARRAY['managed-solution','unmanaged-solution','alm','pl-900'], 'teacher_john', 'teacher_john'),

('concept_pl9_found_dlp01', 'Data Loss Prevention Policies',
 'power platform',
 'DLP policies classify and restrict connector combinations so sensitive organisational data cannot be moved into unsafe services through apps and flows.',
 'An organisation allows Dataverse and Office 365 connectors together but blocks business data from being sent to consumer file-sharing platforms.',
 'DLP policies are like traffic rules that stop sensitive data from taking unsafe roads out of the organisation.',
 'Treating DLP as optional administration instead of a foundational control for safe citizen development.',
 ARRAY['dlp','security','governance','pl-900'], 'teacher_john', 'teacher_john'),

('concept_pl9_found_admincenter01', 'Power Platform Administration Center',
 'power platform',
 'The Power Platform Admin Center is the management hub where administrators monitor environments, policies, capacity, analytics, and governance settings.',
 'An admin uses the Admin Center to create a new environment, review capacity, configure DLP, and inspect tenant-wide usage trends.',
 'The Admin Center is like the control tower for the platform — it gives administrators visibility and control over the whole estate.',
 'Thinking governance happens only in individual apps and flows; tenant-level administration is a foundational part of platform health.',
 ARRAY['admin-center','governance','administration','pl-900'], 'teacher_john', 'teacher_john'),

('concept_pl9_found_makerportal01', 'Maker Portal',
 'power platform',
 'The Maker Portal is the main workspace where makers create, edit, and manage apps, flows, tables, copilots, and other Power Platform assets.',
 'A business analyst opens the Maker Portal to build a canvas app, create a flow, inspect Dataverse tables, and share the solution with teammates.',
 'The Maker Portal is like a workshop where makers assemble and refine the building blocks of a business solution.',
 'Confusing the Maker Portal with the Admin Center; one is for building solutions and the other is for governance and platform administration.',
 ARRAY['maker-portal','maker','power-platform','pl-900'], 'teacher_john', 'teacher_john'),

('concept_pl9_found_templates01', 'Templates as Accelerators',
 'power platform',
 'Templates in Power Platform provide pre-built starting points for apps, flows, pages, and bots so teams can learn patterns quickly and deliver common scenarios faster.',
 'A department starts from a leave-request app template and a matching approval-flow template instead of building both from scratch.',
 'Templates are like training wheels and starter kits combined — they help teams begin with something proven and adapt it to local needs.',
 'Treating templates as finished enterprise solutions; they save time but still need governance, tailoring, and testing.',
 ARRAY['templates','accelerator','low-code','pl-900'], 'teacher_john', 'teacher_john'),

('concept_pl9_found_licensing01', 'Licensing and Capacity Basics',
 'power platform',
 'Licensing and capacity determine which premium capabilities, environments, connectors, AI features, and data storage options an organisation can use at scale.',
 'A team plans a solution using premium connectors and Dataverse capacity, so licensing is reviewed before rollout to avoid surprise blockers later.',
 'Licensing and capacity are like the fuel and permit system for the platform — they affect how far you can go and which routes you are allowed to use.',
 'Designing a solution first and asking about licensing later, only to discover that key components require different plans or extra capacity.',
 ARRAY['licensing','capacity','governance','pl-900'], 'teacher_john', 'teacher_john'),

-- ── Group 2: Power Apps Business Value ───────────────────────────────────────
('concept_pl9_appsvalue01', 'Power Apps Business Value',
 'power platform',
 'Power Apps enables organisations to rapidly build custom business apps that replace paper forms, spreadsheets, and costly custom software with governed, mobile-ready solutions.',
 'A manufacturing firm replaces 12 paper-based inspection checklists with a single Canvas App, reducing data entry errors by 60% and eliminating manual data re-entry.',
 'Power Apps is like a DIY app store for your organisation — instead of waiting months for IT to build a solution, business teams can create and deploy their own in days.',
 'Underestimating app lifecycle management; Power Apps apps still need version control, testing, and owner succession plans to avoid abandoned apps.',
 ARRAY['power-apps','business-value','pl-900'], 'teacher_john', 'teacher_john'),

('concept_pl9_appmodern01', 'App Modernisation',
 'power platform',
 'Replacing legacy desktop applications, Access databases, or paper forms with modern Power Apps solutions that are mobile-friendly, cloud-hosted, and integrated with live data.',
 'An Access database used by 10 staff for inventory tracking is replaced by a Model-Driven App connected to Dataverse, accessible on any device.',
 'App modernisation is like renovating an old building — you keep the business function but replace the crumbling infrastructure with something safe, efficient, and scalable.',
 'Replicating the legacy app exactly instead of rethinking the process; modernisation is the ideal time to improve workflows, not just digitise old ones.',
 ARRAY['power-apps','modernisation','pl-900'], 'teacher_john', 'teacher_john'),

('concept_pl9_mobile01', 'Mobile-First Apps',
 'power platform',
 'Power Apps Canvas Apps are designed to run on iOS and Android devices, enabling field workers to access and update data from anywhere without a laptop.',
 'A site inspector uses a Canvas App on an iPhone to photograph defects, record measurements, and submit reports from the field — all syncing to Dataverse in real time.',
 'Mobile-first apps are like taking your office with you in your pocket — field workers get the same data access and input capabilities as desk-bound colleagues.',
 'Designing Canvas Apps for desktop first and scaling down; always design for the smallest screen (mobile) and scale up for tablet and desktop.',
 ARRAY['power-apps','mobile','field-worker','pl-900'], 'teacher_john', 'teacher_john'),

('concept_pl9_offline01', 'Offline Capability',
 'power platform',
 'Canvas Apps can store data locally when no internet connection is available, syncing changes back to the data source once connectivity is restored.',
 'A utility engineer uses a Canvas App in areas with no signal; completed inspection data is queued locally and uploaded automatically when the device reconnects.',
 'Offline capability is like a notepad that automatically emails your notes when you get back to the office — you capture data on the spot and sync happens later.',
 'Assuming offline capability is automatic; it requires deliberate design using SaveData(), LoadData(), and conflict resolution logic.',
 ARRAY['power-apps','offline','canvas','pl-900'], 'teacher_john', 'teacher_john'),

('concept_pl9_fusionteam01', 'Fusion Development Teams',
 'power platform',
 'A collaboration model where citizen developers (business users) and professional developers work together, with pros building reusable components and citizens assembling solutions.',
 'A pro developer builds a custom PCF control and an Azure API; a business analyst assembles these into a Canvas App using Power Platform without writing backend code.',
 'Fusion teams are like a construction project — architects and engineers design the structural systems, while skilled workers assemble the building from pre-made components.',
 'Treating fusion development as purely citizen-dev with no pro involvement; complex integrations and security requirements need professional developer oversight.',
 ARRAY['fusion-team','pro-dev','citizen-dev','pl-900'], 'teacher_john', 'teacher_john'),

('concept_pl9_powerpages_bv01', 'Power Pages Business Value',
 'power platform',
 'Power Pages enables organisations to build secure, externally-facing websites backed by Dataverse without traditional web development skills, extending data to partners and customers.',
 'A charity builds a volunteer sign-up portal on Power Pages where external users register, view their assignments, and submit reports — all stored in Dataverse.',
 'Power Pages is like a self-service customer portal built on top of your internal database — external users interact with your data through a safe, governed website.',
 'Forgetting that Table Permissions must be configured before going live; without them, portal users cannot read any Dataverse data at all.',
 ARRAY['power-pages','portal','business-value','pl-900'], 'teacher_john', 'teacher_john'),

('concept_pl9_rad01', 'Rapid Application Development (RAD)',
 'power platform',
 'The ability to build and deploy functional business apps in days or weeks rather than months, enabled by Power Apps'' visual development and pre-built templates.',
 'A project manager builds a risk-tracking app in one day using a Power Apps template, customises it over a week, and deploys it to the team the following Monday.',
 'RAD on Power Platform is like using LEGO blocks instead of raw bricks — the blocks are pre-shaped, so you spend time designing, not manufacturing.',
 'Sacrificing quality and governance for speed; RAD should still include data modelling, security review, and user acceptance testing before going live.',
 ARRAY['power-apps','rad','agile','pl-900'], 'teacher_john', 'teacher_john'),

('concept_pl9_aibuilder01', 'AI Builder',
 'power platform',
 'A Power Platform capability that brings pre-built and custom AI models (form processing, object detection, sentiment analysis) into apps and flows without data science expertise.',
 'A procurement team uses AI Builder''s invoice-processing model in a Power Automate flow to automatically extract line items from scanned PDF invoices.',
 'AI Builder is like a plug-in AI assistant for your apps and flows — you configure what you want to detect or extract, and the AI handles the complex model training.',
 'Expecting AI Builder models to be perfectly accurate out of the box; they require training data and ongoing refinement to reach production-ready accuracy.',
 ARRAY['ai-builder','ai','automation','pl-900'], 'teacher_john', 'teacher_john'),

('concept_pl9_template01', 'Power Apps Templates',
 'power platform',
 'Pre-built app templates in Power Apps (e.g. Expense Report, Issue Tracker, Asset Checkout) that give makers a working starting point to customise for their scenario.',
 'A facilities manager starts from the "Asset Checkout" template in Power Apps and customises it for their specific equipment categories and approval workflow in two days.',
 'Templates are like cookie-cutter moulds — they give you the right shape quickly, and you adapt the decoration (fields, logic, branding) to your needs.',
 'Using a template without understanding its data model; templates create their own tables and columns, which may conflict with existing Dataverse customisations.',
 ARRAY['power-apps','templates','pl-900'], 'teacher_john', 'teacher_john'),

('concept_pl9_appsgovernance01', 'Power Apps Governance',
 'power platform',
 'The policies, processes, and tools (DLP, environment strategy, CoE Toolkit) used to ensure Power Apps are secure, compliant, and maintainable across an organisation.',
 'An IT admin uses the CoE Toolkit to identify 200 unused Canvas Apps across the tenant and runs a cleanup campaign, saving storage and reducing security risk.',
 'Power Apps governance is like city planning — without zoning rules and building codes, citizen developers build wherever they like, leading to an unmanageable sprawl.',
 'Implementing governance only after problems arise; governance should be established before enabling broad citizen developer access to the platform.',
 ARRAY['governance','power-apps','admin','pl-900'], 'teacher_john', 'teacher_john'),

-- ── Group 3: Power Automate Business Value ────────────────────────────────────
('concept_pl9_autovalue01', 'Power Automate Business Value',
 'power platform',
 'Power Automate eliminates repetitive manual tasks, reduces human error, and frees employees to focus on higher-value work by automating business processes end-to-end.',
 'An HR team automates onboarding: when a new hire record is created in Dynamics 365, a flow sends welcome emails, creates accounts, and schedules orientation — saving 3 hours per hire.',
 'Power Automate is like a diligent office assistant who never sleeps — it handles routine tasks like sending emails, updating records, and routing approvals without being asked twice.',
 'Automating a broken process without first fixing it; automation amplifies both good and bad processes, so re-engineer before you automate.',
 ARRAY['power-automate','business-value','pl-900'], 'teacher_john', 'teacher_john'),

('concept_pl9_processauto01', 'Digital Process Automation (DPA)',
 'power platform',
 'Automating structured, rules-based business processes across digital systems using Cloud Flows, eliminating manual handoffs and reducing cycle times.',
 'A contract approval process that previously took 5 days of email chains is automated with a Power Automate approval flow, completing in hours with full audit trail.',
 'DPA is like replacing a relay race baton-pass with a conveyor belt — tasks move automatically to the next step without anyone needing to remember to hand off.',
 'Confusing DPA with RPA; DPA uses APIs and connectors to integrate systems directly, while RPA mimics user clicks on screens for legacy systems without APIs.',
 ARRAY['power-automate','dpa','automation','pl-900'], 'teacher_john', 'teacher_john'),

('concept_pl9_rpa_bv01', 'Robotic Process Automation (RPA) Business Value',
 'power platform',
 'RPA via Power Automate Desktop automates repetitive tasks on legacy desktop applications that lack APIs, bridging modern cloud workflows with older systems.',
 'A bank uses Desktop Flows to extract data from a 1990s mainframe terminal and populate a modern Dataverse table nightly — without modifying the mainframe.',
 'RPA is like a robotic arm bolted onto an old manual machine — the machine is not upgraded, but a robot now operates it automatically instead of a human.',
 'Using RPA when a proper API integration is available; RPA should be the last resort due to its fragility when the target UI changes.',
 ARRAY['rpa','power-automate','desktop','pl-900'], 'teacher_john', 'teacher_john'),

('concept_pl9_approvalvalue01', 'Approval Automation Business Value',
 'power platform',
 'Automating approval workflows (expenses, leave, contracts) with Power Automate eliminates email chains, provides auditability, and accelerates decision-making.',
 'A company replaces a 7-day email approval chain for purchase orders with a Power Automate approval flow that managers action in Microsoft Teams, reducing cycle time to 4 hours.',
 'Approval automation is like replacing a paper signature chain with a digital counter that instantly alerts the next approver the moment the previous one signs.',
 'Not handling rejection and escalation paths; approval flows must account for rejections, time-outs, and delegation to be production-ready.',
 ARRAY['power-automate','approval','business-value','pl-900'], 'teacher_john', 'teacher_john'),

('concept_pl9_roiautomation01', 'Automation ROI',
 'power platform',
 'The measurable return on investment from automating a process, calculated by comparing time/cost saved against the cost of building and maintaining the automation.',
 'Automating a 30-minute daily data entry task for 10 employees saves 150 hours/month; at £30/hour that is £4,500/month saved against a one-time build cost of £2,000.',
 'Automation ROI is like compound interest — small time savings per task multiply across employees and months into significant financial returns.',
 'Automating low-frequency, irregular tasks where the build cost outweighs the savings; focus first on high-volume, high-frequency repetitive processes.',
 ARRAY['power-automate','roi','business-value','pl-900'], 'teacher_john', 'teacher_john'),

('concept_pl9_processadvisor01', 'Process Mining',
 'power platform',
 'Power Automate''s process mining capability analyses event logs from business systems to discover how processes actually run, identify bottlenecks, and prioritise automation targets.',
 'Process mining on a purchase order system reveals that 40% of orders get stuck at the same approval step for more than 3 days, making it the top candidate for automation.',
 'Process mining is like a GPS that shows you the actual roads people are taking, not the intended route — it reveals where the real delays and detours are happening.',
 'Skipping process discovery and automating the assumed process; actual process behaviour often differs from documented procedures, leading to ineffective automations.',
 ARRAY['process-mining','power-automate','analytics','pl-900'], 'teacher_john', 'teacher_john'),

('concept_pl9_teamsauto01', 'Microsoft Teams Automation',
 'power platform',
 'Power Automate integrates with Microsoft Teams to send adaptive card notifications, trigger flows from messages, and post approvals directly inside the Teams interface.',
 'A Power Automate flow posts an adaptive card to a Teams channel when a high-priority support ticket is created, allowing the team to acknowledge it with one click.',
 'Teams automation is like adding a smart notification system to your team''s meeting room — important events surface automatically in the place where everyone already works.',
 'Building separate email-based notification flows when Teams is the primary communication tool for the team; meet users where they already work.',
 ARRAY['power-automate','teams','notification','pl-900'], 'teacher_john', 'teacher_john'),

('concept_pl9_errorreduce01', 'Error Reduction through Automation',
 'power platform',
 'Automating manual data entry and handoff tasks eliminates transcription errors, missed steps, and inconsistencies that are common in human-operated processes.',
 'Replacing manual copying of order data from emails into an ERP system with a Power Automate flow reduces data-entry errors from 5% to near zero.',
 'Automation for error reduction is like spell-check for business processes — it catches and prevents mistakes at the source rather than fixing them downstream.',
 'Assuming automation is error-free; automated flows need validation logic and exception handling to catch bad data before it propagates through systems.',
 ARRAY['power-automate','quality','business-value','pl-900'], 'teacher_john', 'teacher_john'),

('concept_pl9_scheduledauto01', 'Scheduled Automation',
 'power platform',
 'Running automations on a fixed schedule (daily, weekly, monthly) to handle batch operations like report generation, data synchronisation, and reminder notifications.',
 'A Scheduled Flow runs every Monday at 8 AM, pulls last week''s sales data from Dataverse, and emails a formatted summary report to each regional manager.',
 'Scheduled automation is like setting a recurring alarm for your business process — the task runs reliably at the same time every cycle without anyone needing to remember.',
 'Running scheduled flows that process all records every time instead of only changed records; always filter for incremental changes to avoid redundant processing.',
 ARRAY['power-automate','schedule','batch','pl-900'], 'teacher_john', 'teacher_john'),

('concept_pl9_connectorvalue01', 'Pre-Built Connectors Value',
 'power platform',
 'Power Automate provides 1,000+ pre-built connectors to popular services (Salesforce, SAP, ServiceNow, Office 365) enabling instant integration without custom development.',
 'A flow connects Salesforce (where leads arrive) to Dataverse (where they are managed) and Outlook (where the sales rep is notified) using three pre-built connectors — no code written.',
 'Pre-built connectors are like pre-wired electrical sockets — you plug your appliance (service) in without needing to understand the wiring behind the wall.',
 'Overlooking connector licensing tiers; many enterprise connectors (SAP, Salesforce) are Premium and require a higher licence tier beyond Microsoft 365.',
 ARRAY['power-automate','connectors','integration','pl-900'], 'teacher_john', 'teacher_john'),

('concept_pl9_cloudflow01', 'Cloud Flow Fundamentals',
 'power platform',
 'A Power Automate automation that runs in Microsoft''s cloud and connects services through triggers and actions, making it ideal for email, approvals, notifications, and cross-system integrations.',
 'When a new row is added to Dataverse, a Cloud Flow sends a Teams alert, creates a Planner task, and writes an audit entry to SharePoint.',
 'A Cloud Flow is like an office workflow coordinator in the cloud — it watches for events and moves work between systems automatically.',
 'Using Cloud Flows for UI-driven legacy desktop tasks that require mouse clicks; those scenarios are better handled by Desktop Flows.',
 ARRAY['power-automate','cloud-flow','automation','pl-900'], 'teacher_john', 'teacher_john'),

('concept_pl9_automatedflow01', 'Automated Cloud Flow',
 'power platform',
 'A type of Cloud Flow that starts automatically when a specific event happens, such as a new email arriving, a SharePoint file being created, or a Dataverse record changing.',
 'A flow triggers automatically when a new Microsoft Form response is submitted, saves the data to Dataverse, and emails a confirmation to the requester.',
 'An Automated Cloud Flow is like a motion-activated light — it wakes up only when something happens and then performs its configured response.',
 'Choosing an automated trigger when the process should run on a schedule or on-demand; not every automation should be event-driven.',
 ARRAY['power-automate','automated-flow','event-driven','pl-900'], 'teacher_john', 'teacher_john'),

('concept_pl9_instantflow01', 'Instant Cloud Flow',
 'power platform',
 'A type of Cloud Flow started manually by a user from Power Automate, Power Apps, Teams, or a mobile device when they want an action to happen immediately.',
 'A sales rep taps a button in a Power Apps app to launch an Instant Flow that sends a quote for approval and posts a message in Teams.',
 'An Instant Flow is like a service bell at a hotel desk — nothing happens until someone presses it, and then the workflow starts immediately.',
 'Building an Instant Flow for a process that should run without user involvement; if it always starts from a system event, an Automated Flow is a better fit.',
 ARRAY['power-automate','instant-flow','manual','pl-900'], 'teacher_john', 'teacher_john'),

('concept_pl9_desktopflow01', 'Desktop Flow',
 'power platform',
 'A Power Automate Desktop automation that records and replays UI steps on a Windows machine, enabling robotic process automation for legacy apps that do not expose APIs.',
 'A finance team uses a Desktop Flow to log into a legacy accounting app, copy invoice data into Excel, and upload the result to SharePoint each evening.',
 'A Desktop Flow is like teaching a robot to operate a keyboard and mouse the same way a human user would on a desktop computer.',
 'Assuming Desktop Flows are as resilient as API-based Cloud Flows; UI automation is more fragile because screen layouts, window titles, and timing can change.',
 ARRAY['power-automate','desktop-flow','rpa','pl-900'], 'teacher_john', 'teacher_john'),

('concept_pl9_triggeraction01', 'Triggers and Actions',
 'power platform',
 'Power Automate flows are built from triggers, which start the flow, and actions, which perform the work such as sending email, creating records, or requesting approval.',
 'A flow uses the trigger "When an item is created" in SharePoint, then runs actions to send an Outlook email and create a task in Planner.',
 'Triggers and actions are like a doorbell and the steps that follow — the bell starts the process, and the actions are what everyone does next.',
 'Designing a flow without clearly identifying the trigger condition, leading to flows that run too often, miss events, or perform duplicate work.',
 ARRAY['power-automate','trigger','action','pl-900'], 'teacher_john', 'teacher_john'),

('concept_pl9_flowtemplate01', 'Power Automate Templates',
 'power platform',
 'Pre-built flow patterns that help makers start common automation scenarios quickly, such as approvals, file notifications, social posting, and data synchronisation.',
 'A department starts from the "Save Office 365 email attachments to OneDrive" template and customises it to route contract files into a governed SharePoint library.',
 'Templates are like recipe cards for automation — they give you the ingredients and steps, and you adapt them to your own kitchen and business rules.',
 'Deploying a template unchanged without reviewing connectors, security, and failure handling; templates are starting points, not production-ready by default.',
 ARRAY['power-automate','templates','starter','pl-900'], 'teacher_john', 'teacher_john'),

('concept_pl9_stdpremium01', 'Standard vs Premium Connectors',
 'power platform',
 'Power Automate connectors are split into standard and premium tiers, which affects licensing, governance decisions, and which automations users can run in production.',
 'A maker builds a flow with Outlook and SharePoint using standard connectors, but adding Salesforce requires a premium licence before the flow can be used broadly.',
 'Standard vs premium connectors are like economy and business-class tickets — both move you forward, but some routes and features cost more.',
 'Designing a solution around premium connectors without checking licensing impact first; the technical design may be fine but the rollout can stall on cost.',
 ARRAY['power-automate','connectors','licensing','pl-900'], 'teacher_john', 'teacher_john'),

('concept_pl9_approvalsconnector01', 'Approvals Connector',
 'power platform',
 'The built-in Power Automate approvals capability used to send approval requests, collect responses, track outcomes, and integrate approval actions with email and Teams.',
 'A leave-request flow uses Start and wait for an approval, notifies the manager in Teams, and updates Dataverse based on Approve or Reject.',
 'The Approvals connector is like a digital in-tray for managers — requests arrive in a standard format, can be actioned quickly, and leave an audit trail behind.',
 'Using plain emails instead of the Approvals actions when approval tracking is required; emails alone do not give the same structured outcome history.',
 ARRAY['power-automate','approvals','connector','pl-900'], 'teacher_john', 'teacher_john'),

('concept_pl9_condition01', 'Condition Control',
 'power platform',
 'A flow control that branches the automation into different paths based on whether a logical test evaluates to true or false.',
 'A flow checks whether an invoice amount is greater than 1000; if true it sends the item for manager approval, otherwise it posts directly to finance processing.',
 'A condition is like a fork in the road — the flow looks at the sign and chooses the right path based on the situation.',
 'Writing conditions against the wrong data type, such as comparing text values as numbers, which causes flows to branch unexpectedly.',
 ARRAY['power-automate','condition','logic','pl-900'], 'teacher_john', 'teacher_john'),

('concept_pl9_applytoeach01', 'Apply to Each Loop',
 'power platform',
 'A looping control in Power Automate that repeats a set of actions for every item in an array or collection returned by a previous step.',
 'A SharePoint query returns 20 overdue tasks and the flow uses Apply to each to send each task owner an individual reminder email.',
 'Apply to each is like working through a stack of forms one by one — the same steps are repeated for every item until the stack is finished.',
 'Putting slow or unnecessary actions inside the loop, which makes the flow take much longer than needed; move shared work outside the loop where possible.',
 ARRAY['power-automate','loop','apply-to-each','pl-900'], 'teacher_john', 'teacher_john'),

('concept_pl9_expression01', 'Expressions',
 'power platform',
 'Inline formulas used in Power Automate to transform data, combine values, test conditions, and manipulate strings, dates, and arrays during a flow run.',
 'A flow uses concat() to build an email subject, formatDateTime() to display a due date, and coalesce() to handle missing values safely.',
 'Expressions are like mini calculator formulas inside a workflow — they let you reshape data without needing to write full application code.',
 'Hard-coding values when an expression should be used, or writing complex expressions without testing them, making the flow brittle and hard to maintain.',
 ARRAY['power-automate','expressions','formula','pl-900'], 'teacher_john', 'teacher_john'),

('concept_pl9_runhistory01', 'Run History',
 'power platform',
 'The monitoring view in Power Automate that shows each flow run, its trigger details, action outcomes, duration, inputs, outputs, and any failures for troubleshooting.',
 'A maker opens run history to see that a flow failed at the SQL action because the gateway connection had expired, then fixes the connection and reruns the flow.',
 'Run history is like a flight recorder for a workflow — it tells you exactly what happened, when it happened, and where things went wrong.',
 'Ignoring run history after deployment; production flows need ongoing monitoring because connection issues, throttling, and data changes can break previously healthy automations.',
 ARRAY['power-automate','monitoring','run-history','pl-900'], 'teacher_john', 'teacher_john'),

('concept_pl9_errorhandling01', 'Error Handling',
 'power platform',
 'The design of flows to detect failures, take fallback actions, notify owners, and continue or stop safely instead of silently breaking when an action fails.',
 'If a record update fails, the flow writes the error to a log list, notifies support in Teams, and marks the item for manual follow-up rather than losing the transaction.',
 'Error handling is like a safety net under a tightrope — problems may still happen, but the process does not crash to the ground without recovery.',
 'Assuming every action will succeed and not planning for timeouts, missing data, rejected approvals, or expired connections.',
 ARRAY['power-automate','error-handling','resilience','pl-900'], 'teacher_john', 'teacher_john'),

('concept_pl9_dataverseauto01', 'Dataverse Automation',
 'power platform',
 'Power Automate works closely with Microsoft Dataverse to trigger flows from table events and create, update, or query business data as part of automated processes.',
 'When a new Case row is created in Dataverse, a flow assigns an owner, sets a priority, creates a follow-up task, and posts a notification to Teams.',
 'Dataverse automation is like wiring your workflow directly into the organisation''s system of record — when the data changes, the business process moves with it.',
 'Treating Dataverse triggers as if they were simple spreadsheet updates; row ownership, security, and trigger conditions must still be considered carefully.',
 ARRAY['power-automate','dataverse','automation','pl-900'], 'teacher_john', 'teacher_john'),

('concept_pl9_mobileflow01', 'Power Automate Mobile App',
 'power platform',
 'The mobile app lets users receive approvals, trigger instant flows, monitor runs, and stay connected to business automations from a phone or tablet.',
 'A regional manager approves an urgent purchase request from the Power Automate mobile app while travelling, preventing a same-day order from being delayed.',
 'The mobile app is like carrying your workflow inbox in your pocket — you can respond to requests and launch actions without being at your desk.',
 'Designing approval or instant-flow experiences that only work well on desktop; mobile users need short forms, clear inputs, and simple actions.',
 ARRAY['power-automate','mobile','approvals','pl-900'], 'teacher_john', 'teacher_john'),

-- ── Group 4: Power BI Business Value ─────────────────────────────────────────
('concept_pl9_bivalue01', 'Power BI Business Value',
 'power platform',
 'Power BI transforms raw data into interactive visualisations and reports that enable faster, evidence-based decisions across all levels of an organisation.',
 'A retail chain replaces weekly Excel-based sales reports emailed to managers with a live Power BI dashboard, cutting report preparation time from 8 hours to zero.',
 'Power BI is like upgrading from a printed map to a live GPS — instead of a static snapshot of where you were, you see exactly where you are and where you are heading.',
 'Building reports without understanding the audience; Power BI''s value comes from delivering the right insight to the right person, not creating the most complex dashboard.',
 ARRAY['power-bi','business-value','analytics','pl-900'], 'teacher_john', 'teacher_john'),

('concept_pl9_selfservicebi01', 'Self-Service BI',
 'power platform',
 'The ability for business users to create their own reports and dashboards from governed datasets without depending on IT or data analysts for every query.',
 'A marketing manager connects Power BI Desktop to a certified dataset and builds her own campaign-performance dashboard without raising an IT ticket.',
 'Self-service BI is like giving everyone in the office a key to the data filing cabinet — instead of asking IT to retrieve files, users find what they need themselves.',
 'Confusing self-service access with ungoverned data; self-service BI should be built on certified, IT-approved datasets to ensure consistent, trustworthy numbers.',
 ARRAY['power-bi','self-service','analytics','pl-900'], 'teacher_john', 'teacher_john'),

('concept_pl9_pbidesktop01', 'Power BI Desktop',
 'power platform',
 'A free Windows application for connecting to data sources, transforming data with Power Query, building data models, and authoring reports before publishing to the Power BI Service.',
 'A data analyst uses Power BI Desktop to connect to Azure SQL, clean data with Power Query, build a star-schema model, and design a sales report before publishing it.',
 'Power BI Desktop is like a professional kitchen where you prepare the meal (data model and report) before serving it (publishing to the service for others to consume).',
 'Doing all data transformation inside the report visuals instead of Power Query; complex calculations belong in the data model, not the visual layer.',
 ARRAY['power-bi','desktop','authoring','pl-900'], 'teacher_john', 'teacher_john'),

('concept_pl9_pbiservice01', 'Power BI Service',
 'power platform',
 'A cloud-based platform where published Power BI reports are shared, scheduled for data refresh, embedded, and consumed by business users across the organisation.',
 'A finance analyst publishes a monthly close dashboard to the Power BI Service, sets a daily data refresh, and shares it with the CFO''s team via a workspace.',
 'The Power BI Service is like a digital newsstand — the analyst (journalist) creates and publishes the report, and subscribers read it in the cloud on any device.',
 'Confusing Power BI Desktop (authoring tool) with the Power BI Service (publishing and sharing platform); they are separate tools with different roles.',
 ARRAY['power-bi','service','sharing','pl-900'], 'teacher_john', 'teacher_john'),

('concept_pl9_pbireport01', 'Power BI Report',
 'power platform',
 'A multi-page, interactive document created in Power BI Desktop containing visuals (charts, tables, maps) connected to a data model, enabling exploratory data analysis.',
 'A sales report contains a bar chart of revenue by region, a line chart of monthly trends, and a map of top customers — all filtering each other when clicked.',
 'A Power BI report is like an interactive magazine — instead of static printed charts, every visual is linked, and clicking one filters the others dynamically.',
 'Building one massive report with 20 pages; split by audience and purpose — simpler, focused reports are more adopted than comprehensive but confusing ones.',
 ARRAY['power-bi','report','visualisation','pl-900'], 'teacher_john', 'teacher_john'),

('concept_pl9_pbidashboard01', 'Power BI Dashboard',
 'power platform',
 'A single-page canvas in the Power BI Service that displays pinned tiles from multiple reports, providing a high-level real-time overview for executives and decision-makers.',
 'A CEO''s Power BI dashboard shows revenue-to-target, headcount, customer NPS, and open support tickets — all pinned from four different underlying reports.',
 'A Power BI dashboard is like a cockpit instrument panel — it shows the critical gauges from multiple systems in one glance, alerting you when something needs attention.',
 'Confusing a dashboard with a report; dashboards are a curated summary of KPIs pinned from reports, not a place to do exploratory analysis.',
 ARRAY['power-bi','dashboard','executive','pl-900'], 'teacher_john', 'teacher_john'),

('concept_pl9_datarefresh01', 'Data Refresh',
 'power platform',
 'The scheduled or on-demand process by which Power BI re-queries the data source and updates the report''s underlying dataset to reflect the latest information.',
 'A sales dashboard is configured with an 8x daily data refresh, so managers always see figures no more than 3 hours old without needing to manually update anything.',
 'Data refresh is like a newspaper printing a new edition — without it, readers see yesterday''s news; with a frequent schedule, the information stays current.',
 'Assuming reports show live data by default; Power BI imports data into a dataset, and without scheduled refresh the data becomes stale after the initial load.',
 ARRAY['power-bi','refresh','data','pl-900'], 'teacher_john', 'teacher_john'),

('concept_pl9_pbimobile01', 'Power BI Mobile',
 'power platform',
 'iOS and Android apps that allow business users to access Power BI dashboards and reports from their phones, with touch-optimised layouts and push notifications for alerts.',
 'A regional manager receives a push notification on his phone when the daily sales target falls below 80%, then opens Power BI Mobile to drill into the underperforming stores.',
 'Power BI Mobile is like carrying a live business newspaper in your pocket — you get alerts for breaking news (data anomalies) and can dig into the story anywhere.',
 'Not creating mobile-optimised report layouts; the default desktop layout is hard to read on a phone — use the mobile layout view in Power BI Desktop.',
 ARRAY['power-bi','mobile','analytics','pl-900'], 'teacher_john', 'teacher_john'),

('concept_pl9_datadriven01', 'Data-Driven Decision Making',
 'power platform',
 'The practice of basing business decisions on data analysis and visualisation rather than gut instinct, enabled by accessible tools like Power BI.',
 'A marketing team reviews a Power BI report showing which channels drive the lowest cost-per-lead, then reallocates budget from TV to digital — increasing leads by 30%.',
 'Data-driven decision making is like navigating with a map instead of guessing — you see the evidence, choose the most promising route, and measure whether it worked.',
 'Mistaking correlation for causation in data; Power BI surfaces patterns but humans must apply context and business knowledge to avoid drawing wrong conclusions.',
 ARRAY['power-bi','analytics','business-value','pl-900'], 'teacher_john', 'teacher_john'),

('concept_pl9_datasharing01', 'Power BI Sharing and Workspaces',
 'power platform',
 'Power BI Workspaces enable teams to collaborate on reports, and sharing features let analysts publish content to specific users or broad organisational audiences.',
 'A finance team uses a Power BI Workspace to co-develop reports; once approved, the content is published to an App for the wider business to consume in read-only mode.',
 'Workspaces are like a shared project folder — the team edits inside the workspace, and publishing an App is like printing the finished document for everyone to read.',
 'Sharing individual reports directly instead of publishing an App; direct sharing becomes unmanageable at scale and does not provide a curated, versioned experience.',
 ARRAY['power-bi','sharing','workspace','pl-900'], 'teacher_john', 'teacher_john'),

('concept_pl9_semanticmodel01', 'Power BI Semantic Model',
 'power platform',
 'A semantic model, formerly called a dataset, is the structured layer in Power BI that stores tables, relationships, calculations, and business logic used by reports.',
 'A finance team builds one semantic model for revenue and cost data, then creates separate executive, sales, and operations reports from that shared model.',
 'A semantic model is like the organised library behind a report — the shelves, labels, and cataloguing system make it easy for everyone to find the right insight.',
 'Treating every report as if it needs its own separate model; shared semantic models improve consistency and reduce duplicate definitions of key metrics.',
 ARRAY['power-bi','semantic-model','dataset','pl-900'], 'teacher_john', 'teacher_john'),

('concept_pl9_powerquery01', 'Power Query',
 'power platform',
 'Power Query is the data preparation tool in Power BI used to connect to sources, clean data, combine tables, and shape information before it enters the model.',
 'An analyst uses Power Query to split full names, remove duplicate rows, merge sales files from multiple regions, and standardise date formats.',
 'Power Query is like a prep kitchen where raw ingredients are washed, chopped, and organised before they become the final meal.',
 'Trying to fix all data issues inside visuals or DAX instead of cleaning them early in Power Query, which makes reports harder to maintain.',
 ARRAY['power-bi','power-query','data-prep','pl-900'], 'teacher_john', 'teacher_john'),

('concept_pl9_datasource01', 'Data Sources',
 'power platform',
 'Power BI connects to many data sources including Excel, SQL Server, SharePoint, Dataverse, Azure services, and SaaS platforms so organisations can analyse information from across the business.',
 'A report combines data from Excel budget files, SQL sales history, and Dataverse account records to give managers one consolidated view.',
 'Data sources are like rivers feeding a reservoir — Power BI gathers information from many places and brings it into one analysis environment.',
 'Connecting to too many uncontrolled spreadsheets when governed system data already exists, which undermines trust in the report results.',
 ARRAY['power-bi','data-sources','integration','pl-900'], 'teacher_john', 'teacher_john'),

('concept_pl9_visuals01', 'Data Visualisations',
 'power platform',
 'Charts, tables, maps, cards, and other visuals in Power BI turn raw numbers into patterns and stories that business users can understand quickly.',
 'A sales report uses a line chart for monthly trends, a bar chart for top products, and a card visual for total revenue to summarise performance clearly.',
 'Visualisations are like turning a spreadsheet into a picture book — the same facts become much easier to scan and interpret.',
 'Using flashy or inappropriate chart types that look impressive but make the data harder to read than a simpler visual would.',
 ARRAY['power-bi','visualisation','reporting','pl-900'], 'teacher_john', 'teacher_john'),

('concept_pl9_kpi01', 'Key Performance Indicators (KPIs)',
 'power platform',
 'KPIs are measurable business targets shown in Power BI to track whether performance is meeting expectations, such as revenue target, case resolution time, or customer satisfaction.',
 'A dashboard shows monthly revenue against target with a green indicator when performance exceeds plan and red when it falls behind.',
 'KPIs are like the scoreboards in a stadium — they show at a glance whether the team is winning, losing, or on target.',
 'Choosing too many KPIs so the dashboard becomes noisy; the most useful KPI dashboards focus on a small number of truly decision-driving measures.',
 ARRAY['power-bi','kpi','dashboard','pl-900'], 'teacher_john', 'teacher_john'),

('concept_pl9_slicers01', 'Filters and Slicers',
 'power platform',
 'Filters and slicers let users narrow a report to the data most relevant to them, such as a specific region, product line, date range, or department.',
 'A manager selects only the South Island region and Q1 in slicers to see the relevant sales figures update across all visuals instantly.',
 'Filters and slicers are like choosing which lenses to look through — the data stays the same, but you focus on the part that matters right now.',
 'Adding too many slicers to a page or using confusing labels, which overwhelms users and makes the report harder to navigate.',
 ARRAY['power-bi','filters','slicers','pl-900'], 'teacher_john', 'teacher_john'),

('concept_pl9_drill01', 'Drill-Down and Drill-Through',
 'power platform',
 'Drill-down and drill-through features let users move from high-level summary data into more detailed views to investigate the drivers behind a result.',
 'A regional sales chart lets a director drill from country to region to store, then drill through to a page showing the detailed transactions behind one store''s drop in sales.',
 'Drill features are like moving from a city map to a street map and then to a specific address — each step gives more detail when you need it.',
 'Building only high-level summary pages and leaving users unable to explore why a number changed or where a problem originated.',
 ARRAY['power-bi','drill-down','drill-through','pl-900'], 'teacher_john', 'teacher_john'),

('concept_pl9_qna01', 'Q&A Natural Language Queries',
 'power platform',
 'Power BI Q&A lets users type business questions in natural language and receive suggested visuals or answers without building the report manually.',
 'A user asks "total sales by region this quarter" and Power BI generates a chart showing the answer directly from the model.',
 'Q&A is like asking a data analyst a plain-English question and getting a chart back immediately.',
 'Expecting Q&A to work well without a clean semantic model and friendly field names; the quality of answers depends heavily on good model design.',
 ARRAY['power-bi','q-and-a','natural-language','pl-900'], 'teacher_john', 'teacher_john'),

('concept_pl9_alerts01', 'Data Alerts',
 'power platform',
 'Data alerts notify users when a dashboard metric crosses a threshold, helping them act quickly when business conditions change.',
 'A warehouse manager receives a Power BI alert when inventory for a critical product falls below the minimum stock threshold.',
 'Data alerts are like a smoke alarm for business metrics — they stay quiet when things are normal and get attention when a threshold is crossed.',
 'Setting too many alerts with poor thresholds, which leads to alert fatigue and causes users to ignore genuinely important notifications.',
 ARRAY['power-bi','alerts','monitoring','pl-900'], 'teacher_john', 'teacher_john'),

('concept_pl9_rls01', 'Row-Level Security (RLS)',
 'power platform',
 'Row-level security restricts which rows of data a user can see in a Power BI report, enabling one report to serve multiple audiences safely.',
 'A sales report uses RLS so each regional manager sees only their own territory''s customers and revenue while executives see all regions.',
 'RLS is like issuing the same report book to everyone but blacking out the pages each person is not allowed to read.',
 'Publishing a report with sensitive data and assuming workspace membership alone is enough; RLS must be configured when different users need different views of the same data.',
 ARRAY['power-bi','security','rls','pl-900'], 'teacher_john', 'teacher_john'),

('concept_pl9_pbiapp01', 'Power BI Apps',
 'power platform',
 'A Power BI App is a packaged, curated way to distribute dashboards and reports from a workspace to a wider audience in a controlled read-only experience.',
 'The finance team publishes a monthly reporting app containing approved dashboards for executives, branch managers, and analysts.',
 'A Power BI App is like publishing a finished magazine from an editorial workspace — readers get a polished edition without seeing the draft material.',
 'Sharing workspace access with every consumer instead of publishing an app; broad workspace access creates clutter and increases the risk of accidental edits.',
 ARRAY['power-bi','app','sharing','pl-900'], 'teacher_john', 'teacher_john'),

('concept_pl9_gateway01', 'On-Premises Data Gateway',
 'power platform',
 'The on-premises data gateway securely connects Power BI Service to data sources that remain inside an organisation''s local network, enabling refresh without moving the source system to the cloud.',
 'A company keeps SQL Server on-premises but uses a gateway so its Power BI sales dashboard refreshes every morning in the cloud service.',
 'A gateway is like a secure tunnel between your office server room and the Power BI cloud.',
 'Assuming cloud reports can refresh on-premises data automatically; without a properly configured gateway, scheduled refresh and live access will fail.',
 ARRAY['power-bi','gateway','on-premises','pl-900'], 'teacher_john', 'teacher_john'),

('concept_pl9_importdirect01', 'Import vs DirectQuery',
 'power platform',
 'Power BI supports different storage modes: Import copies data into the model for speed, while DirectQuery leaves data in the source system and queries it live.',
 'A fast executive dashboard uses imported historical sales data, while an operational dashboard uses DirectQuery to show near-real-time warehouse activity.',
 'Import vs DirectQuery is like keeping a local copy of a book for faster reading versus checking the library shelf every time you need a page.',
 'Choosing DirectQuery for every scenario because it sounds more real-time; it often comes with performance and modelling limitations compared with Import.',
 ARRAY['power-bi','import','directquery','pl-900'], 'teacher_john', 'teacher_john'),

('concept_pl9_dax01', 'DAX Measures',
 'power platform',
 'DAX is the formula language used in Power BI to create measures and calculations such as totals, percentages, year-to-date values, and growth rates.',
 'A model includes a DAX measure for Gross Margin % and another for Year-to-Date Sales so executives see the most important business calculations consistently across reports.',
 'DAX measures are like custom formulas on a financial calculator — they define how Power BI should compute business answers from the underlying data.',
 'Creating many similar measures with inconsistent definitions across reports; core business metrics should be standardised in the semantic model.',
 ARRAY['power-bi','dax','measures','pl-900'], 'teacher_john', 'teacher_john'),

('concept_pl9_dataflow01', 'Dataflows',
 'power platform',
 'Dataflows let organisations centralise reusable data preparation in the Power BI Service so multiple reports can consume the same cleaned and transformed data.',
 'A retail team builds one customer-cleaning dataflow and reuses it across sales, loyalty, and marketing reports instead of repeating the same steps three times.',
 'Dataflows are like a shared prep station in a restaurant — one team cleans and prepares the ingredients once, and many dishes can use them.',
 'Rebuilding the same transformation logic in every report rather than creating reusable preparation layers where appropriate.',
 ARRAY['power-bi','dataflow','reuse','pl-900'], 'teacher_john', 'teacher_john'),

-- ── Group 5: Copilot Studio Business Value ────────────────────────────────────
('concept_pl9_copilotstudio01', 'Copilot Studio',
 'power platform',
 'A low-code platform for building AI-powered chatbots and copilots that can answer questions, automate tasks, and integrate with business data — without writing AI code.',
 'A customer service team builds a Copilot Studio bot that answers common product questions, looks up order status in Dataverse, and escalates complex issues to a human agent.',
 'Copilot Studio is like a smart receptionist you train with your own knowledge — you define the topics it knows about, and it handles customer queries automatically.',
 'Building a bot without defining a clear scope of what it should and should not answer; unbounded bots confuse users and are expensive to maintain.',
 ARRAY['copilot-studio','chatbot','ai','pl-900'], 'teacher_john', 'teacher_john'),

('concept_pl9_chatbot01', 'Chatbot Business Value',
 'power platform',
 'Chatbots built in Copilot Studio handle repetitive customer or employee queries 24/7, reducing support ticket volume and improving response times without increasing headcount.',
 'A company deploys an HR chatbot that answers 70% of common questions (leave balance, payslip access, policy queries) without human involvement, freeing HR staff for complex cases.',
 'A chatbot is like an always-available FAQ page that talks back — users get instant answers at any hour without waiting for a human to respond.',
 'Measuring chatbot success only by deflection rate; also measure customer satisfaction, escalation quality, and whether escalated cases are resolved faster.',
 ARRAY['copilot-studio','chatbot','business-value','pl-900'], 'teacher_john', 'teacher_john'),

('concept_pl9_intent01', 'Intent Recognition',
 'power platform',
 'The AI capability in Copilot Studio that understands the meaning behind a user''s message — even if phrased differently each time — and routes it to the correct topic.',
 'A user types "I need a day off next Friday" or "how do I book leave" — different phrasings that both trigger the same Leave Request topic in the bot.',
 'Intent recognition is like a well-trained customer service rep who understands what you mean even if you do not use the exact right words.',
 'Relying solely on intent AI without providing example phrases (trigger phrases); without enough examples, the model routes queries to wrong topics.',
 ARRAY['copilot-studio','nlp','ai','pl-900'], 'teacher_john', 'teacher_john'),

('concept_pl9_topics01', 'Copilot Studio Topics',
 'power platform',
 'A Topic in Copilot Studio defines a conversation path the bot follows when a user''s message matches its trigger phrases, containing questions, conditions, and actions.',
 'A "Track My Order" topic asks for the order number, calls a Power Automate flow to look up the status, and replies with the delivery date.',
 'Topics are like conversation scripts for the bot — when a user says the right trigger words, the bot follows the script for that scenario.',
 'Creating too many overlapping topics with similar trigger phrases, causing the bot to frequently route to the wrong topic or ask for disambiguation.',
 ARRAY['copilot-studio','topics','conversation','pl-900'], 'teacher_john', 'teacher_john'),

('concept_pl9_copilotactions01', 'Copilot Studio Actions',
 'power platform',
 'Actions in Copilot Studio connect a bot to real data and systems by calling Power Automate flows, HTTP APIs, or Dataverse queries within a conversation.',
 'During a conversation, the bot calls a Power Automate flow action to create a support ticket in Dataverse and returns the ticket number to the user.',
 'Actions are the bot''s hands — topics define what the bot says, while actions let it reach out and do things in connected systems on the user''s behalf.',
 'Putting all logic directly in the bot topic instead of a reusable Power Automate flow; flows are easier to test, maintain, and reuse across multiple topics.',
 ARRAY['copilot-studio','actions','integration','pl-900'], 'teacher_john', 'teacher_john'),

('concept_pl9_omnichannel01', 'Omnichannel Deployment',
 'power platform',
 'Copilot Studio bots can be published to multiple channels — Microsoft Teams, websites, mobile apps, Facebook, and more — from a single bot definition.',
 'A customer service bot is published to the company website and to Microsoft Teams simultaneously; employees and customers both use it but through their preferred channel.',
 'Omnichannel deployment is like broadcasting the same TV programme on multiple channels — the content is the same, but viewers choose their preferred screen.',
 'Building separate bots for each channel; one bot published to multiple channels is far more maintainable than maintaining parallel bots with duplicated logic.',
 ARRAY['copilot-studio','omnichannel','deployment','pl-900'], 'teacher_john', 'teacher_john'),

('concept_pl9_escalation01', 'Handoff to Live Agent',
 'power platform',
 'Copilot Studio can transfer a conversation to a human agent when the bot cannot resolve the query, passing full conversation context to avoid the user repeating themselves.',
 'When a customer''s complaint exceeds the bot''s capability, the bot transfers the full chat transcript to an available agent in Dynamics 365 Customer Service.',
 'Handoff to a live agent is like a receptionist transferring a call — the caller does not have to explain everything again because the receptionist briefs the next person.',
 'Not configuring escalation at all; every bot needs a graceful escalation path for queries it cannot handle, or users will abandon in frustration.',
 ARRAY['copilot-studio','escalation','customer-service','pl-900'], 'teacher_john', 'teacher_john'),

('concept_pl9_botanalytics01', 'Bot Analytics',
 'power platform',
 'Copilot Studio provides built-in analytics showing session volumes, resolution rates, escalation rates, and abandoned topics to help makers improve bot performance over time.',
 'Analytics show that 35% of sessions end in escalation on the "Billing" topic; the maker adds more phrases and answers to that topic, dropping escalation to 15%.',
 'Bot analytics are like a feedback form for your chatbot — they show which conversations went well, which fell flat, and exactly where to focus improvement efforts.',
 'Deploying a bot and never reviewing analytics; bots require continuous improvement based on real conversation data to maintain and improve resolution rates.',
 ARRAY['copilot-studio','analytics','improvement','pl-900'], 'teacher_john', 'teacher_john'),

('concept_pl9_knowledgebase01', 'Knowledge Base Integration',
 'power platform',
 'Copilot Studio can connect to SharePoint sites, public websites, or uploaded documents to automatically generate answers from existing organisational knowledge.',
 'A Copilot Studio bot is connected to the company''s SharePoint HR policy library; employees ask policy questions and the bot finds and summarises the relevant document.',
 'Knowledge base integration is like giving the bot a library card — instead of hand-crafting every answer, it reads from the organisation''s existing documents.',
 'Connecting the bot to unstructured or outdated knowledge bases; the quality of the bot''s answers is only as good as the quality of the source documents.',
 ARRAY['copilot-studio','knowledge-base','ai','pl-900'], 'teacher_john', 'teacher_john'),

('concept_pl9_generativeai01', 'Generative AI in Copilot Studio',
 'power platform',
 'Copilot Studio integrates generative AI (powered by Azure OpenAI) to allow bots to answer questions from connected knowledge sources using natural language generation.',
 'Without hand-crafting every topic, the bot reads from a SharePoint knowledge base and generates fluent, contextually relevant answers to employee policy questions.',
 'Generative AI in Copilot Studio is like upgrading from a scripted call centre to a knowledgeable human agent — responses are natural and context-aware, not rigid scripts.',
 'Relying entirely on generative AI without guardrails; configure topic-level controls and test thoroughly to prevent the bot from generating inaccurate or inappropriate responses.',
 ARRAY['copilot-studio','generative-ai','azure-openai','pl-900'], 'teacher_john', 'teacher_john'),

-- ── Group 6: Power Pages & Power Virtual Agents ──────────────────────────────
('concept_pl9_pages01', 'Power Pages Fundamentals',
 'power platform',
 'A low-code platform for building secure, external-facing business websites connected to Dataverse, enabling organisations to share data and processes with customers, partners, and citizens.',
 'A local council uses Power Pages to publish a permit application portal where residents submit requests, upload documents, and track status online.',
 'Power Pages is like building a front desk for your Dataverse data — external users can interact with selected information without entering your internal apps.',
 'Treating Power Pages like an internal Power Apps screen; website users, authentication, and public-facing security need different planning than internal business apps.',
 ARRAY['power-pages','portal','website','pl-900'], 'teacher_john', 'teacher_john'),

('concept_pl9_pagesbiz01', 'Power Pages Value',
 'power platform',
 'Power Pages reduces the cost and time of delivering self-service websites by letting organisations create secure portals without building a custom web application from scratch.',
 'A university launches a scholarship application portal in weeks using Power Pages instead of commissioning a bespoke public website project that would take months.',
 'Power Pages business value is like opening an online service counter — customers help themselves online instead of relying on staff to process everything manually.',
 'Focusing only on the website launch speed; long-term governance, support ownership, and content maintenance are also part of the value equation.',
 ARRAY['power-pages','business-value','pl-900'], 'teacher_john', 'teacher_john'),

('concept_pl9_pagesportal01', 'Self-Service Portal',
 'power platform',
 'A website pattern where external users can submit requests, update details, check case status, and access information on their own without needing staff intervention.',
 'An insurance company lets customers log into a Power Pages portal to update policy details, upload claim photos, and check claim progress.',
 'A self-service portal is like an online reception desk that stays open 24/7 and answers routine requests without a human receptionist.',
 'Publishing a portal without identifying which journeys should be self-service; not every complex process is suitable for end users without staff assistance.',
 ARRAY['power-pages','self-service','portal','pl-900'], 'teacher_john', 'teacher_john'),

('concept_pl9_pagespartner01', 'Partner Portal',
 'power platform',
 'A Power Pages site designed for suppliers, resellers, distributors, or contractors to collaborate with the organisation through controlled access to shared data and processes.',
 'A manufacturer gives suppliers access to a partner portal where they confirm purchase orders, update delivery dates, and view payment status.',
 'A partner portal is like a shared project room for outside organisations — they can see only the documents and tasks relevant to their role.',
 'Giving every partner the same broad access instead of segmenting by account, geography, or role, which increases the risk of data leakage.',
 ARRAY['power-pages','partner-portal','external-users','pl-900'], 'teacher_john', 'teacher_john'),

('concept_pl9_pagestemplate01', 'Power Pages Templates',
 'power platform',
 'Pre-built website templates that provide a starting structure for common scenarios such as scheduling, registrations, community portals, and customer support sites.',
 'A nonprofit starts from a Power Pages event-registration template and customises branding, forms, and Dataverse tables for its volunteer programme.',
 'Templates are like pre-furnished show homes — the layout is already there, and you adapt it to fit your own needs and brand.',
 'Assuming a template is production-ready out of the box; templates still need security review, data model validation, and content cleanup before launch.',
 ARRAY['power-pages','templates','website','pl-900'], 'teacher_john', 'teacher_john'),

('concept_pl9_pagesdesign01', 'Power Pages Design Studio',
 'power platform',
 'The visual authoring experience used to create pages, forms, lists, navigation, styles, and site content for a Power Pages website.',
 'A maker uses Design Studio to add a new application form, reorder navigation links, and update the portal homepage banner without writing custom front-end code.',
 'Design Studio is like a website control room — you adjust the layout, content, and connected components from one visual workspace.',
 'Treating Design Studio like a full replacement for web development in every case; advanced branding and client-side behaviour may still require developer involvement.',
 ARRAY['power-pages','design-studio','maker','pl-900'], 'teacher_john', 'teacher_john'),

('concept_pl9_pagesdataverse01', 'Dataverse Integration for Power Pages',
 'power platform',
 'Power Pages uses Dataverse as its primary data platform, allowing website forms, lists, and business processes to read and write governed data already used elsewhere in Power Platform.',
 'A student-application portal writes submissions to Dataverse, where a model-driven app used by admissions staff reviews and processes those same records.',
 'Dataverse integration is like connecting your public website directly to the same filing system your internal team already uses — one source of truth powers both.',
 'Creating separate duplicate data stores for the website when Dataverse already contains the right entities, causing synchronisation and reporting headaches.',
 ARRAY['power-pages','dataverse','integration','pl-900'], 'teacher_john', 'teacher_john'),

('concept_pl9_pagesauth01', 'Authentication Providers',
 'power platform',
 'Authentication providers let external users sign in to Power Pages using identities such as Microsoft Entra ID, local accounts, or third-party identity providers.',
 'A partner portal uses Entra ID B2B so suppliers sign in with their own organisational accounts instead of separate usernames and passwords.',
 'Authentication providers are like the front gate of a building — they decide who is allowed in and how visitors prove their identity.',
 'Turning on a sign-in provider without planning user lifecycle and support processes such as invitation, password reset, and account deactivation.',
 ARRAY['power-pages','authentication','identity','pl-900'], 'teacher_john', 'teacher_john'),

('concept_pl9_pagesanon01', 'Anonymous vs Authenticated Access',
 'power platform',
 'Power Pages can expose some pages publicly while restricting other pages to signed-in users, allowing organisations to balance open information with secure transactions.',
 'A city website publishes general permit guidance anonymously but requires sign-in before residents can submit an application or view its status.',
 'Anonymous vs authenticated access is like the public lobby versus staff-only offices in a building — some spaces are open to everyone, others require a badge.',
 'Accidentally exposing sensitive content on pages intended for signed-in users only; access design must be reviewed page by page, not assumed globally.',
 ARRAY['power-pages','security','access','pl-900'], 'teacher_john', 'teacher_john'),

('concept_pl9_pageswebroles01', 'Web Roles',
 'power platform',
 'Web Roles group website users into access categories so that Power Pages can control which pages, content, and data each type of external user can see or use.',
 'A portal has separate web roles for Students, Lecturers, and Administrators, each seeing different pages and navigation options after sign-in.',
 'Web roles are like coloured wristbands at an event — each colour grants access to a different set of areas and activities.',
 'Assigning every user the same web role because it is faster; this removes the least-privilege model and makes future security reviews much harder.',
 ARRAY['power-pages','web-roles','security','pl-900'], 'teacher_john', 'teacher_john'),

('concept_pl9_pagestableperm01', 'Table Permissions',
 'power platform',
 'Table Permissions define which Dataverse rows a Power Pages user can create, read, update, append, or delete when interacting with data through the website.',
 'A student can read and update only their own application record because the portal applies a self-scoped Table Permission on the Application table.',
 'Table Permissions are like row-level security guards for your website — they check each attempted data action and only allow access to the right records.',
 'Configuring a form or list and assuming it is secure by default; without matching Table Permissions, either data access fails or unsafe exposure can occur.',
 ARRAY['power-pages','table-permissions','dataverse','pl-900'], 'teacher_john', 'teacher_john'),

('concept_pl9_pagessecurity01', 'Power Pages Security Model',
 'power platform',
 'The combination of authentication, web roles, page permissions, and table permissions that protects website content and underlying Dataverse data.',
 'A membership portal allows anonymous browsing of programme information, requires sign-in to apply, and restricts each member to their own records using layered permissions.',
 'The Power Pages security model is like a building security system with locks, badges, and room-level access rules all working together.',
 'Testing only the happy path as an administrator; always verify what an unauthenticated user and a normal portal user can actually see and do.',
 ARRAY['power-pages','security','governance','pl-900'], 'teacher_john', 'teacher_john'),

('concept_pl9_pagesformslists01', 'Forms and Lists in Power Pages',
 'power platform',
 'Forms and lists let website users submit, view, and update Dataverse data through browser-based experiences without building custom CRUD pages from scratch.',
 'A supplier portal shows a list of open orders and a form for updating shipping references directly against Dataverse records.',
 'Forms and lists are like ready-made service windows on a website — one lets users hand in information, and the other lets them review what is already on file.',
 'Adding forms and lists without simplifying the experience for external users; internal table structure often needs a cleaner website-facing design.',
 ARRAY['power-pages','forms','lists','pl-900'], 'teacher_john', 'teacher_john'),

('concept_pl9_pagesusecase01', 'External Website Use Cases',
 'power platform',
 'Common Power Pages scenarios include customer service portals, permit applications, supplier onboarding, grant applications, volunteer registration, and service request tracking.',
 'A healthcare provider uses Power Pages for patient intake forms and appointment-request tracking before the patient ever enters the internal system.',
 'Power Pages use cases are like digital front counters for specific business journeys — each one gives outside users a direct route into a service.',
 'Trying to fit every public web need into Power Pages; some high-scale marketing sites or heavily custom experiences may still be better served by traditional web platforms.',
 ARRAY['power-pages','use-cases','external-site','pl-900'], 'teacher_john', 'teacher_john'),

('concept_pl9_pva01', 'Power Virtual Agents',
 'power platform',
 'Power Virtual Agents, now part of Copilot Studio, lets makers create conversational bots that answer questions, guide users, and automate simple tasks without traditional bot coding.',
 'An IT helpdesk bot built with Power Virtual Agents answers password-reset questions and launches a reset workflow when needed.',
 'Power Virtual Agents is like building a digital receptionist that can talk to users, follow a script, and hand off work to other systems.',
 'Thinking of Power Virtual Agents as a general AI that can answer anything; it still needs clear scope, content, and governance.',
 ARRAY['power-virtual-agents','copilot-studio','bot','pl-900'], 'teacher_john', 'teacher_john'),

('concept_pl9_pvabiz01', 'Virtual Agents Business Value',
 'power platform',
 'Virtual agents reduce repetitive support workload, improve response times, and make common information and actions available to users around the clock.',
 'A university chatbot handles routine timetable, campus-location, and enrolment-status questions 24/7, reducing first-line support calls by 40%.',
 'Virtual agents are like adding a first-line support desk that never closes and can resolve routine requests instantly.',
 'Measuring value only by ticket deflection; user satisfaction, answer accuracy, and smooth escalation are equally important.',
 ARRAY['power-virtual-agents','business-value','chatbot','pl-900'], 'teacher_john', 'teacher_john'),

('concept_pl9_pvatrigger01', 'Trigger Phrases',
 'power platform',
 'Trigger phrases are sample user utterances that help a virtual agent recognise when a specific topic or conversation path should start.',
 'A Leave Request topic includes trigger phrases like "book leave", "take annual leave", and "request time off".',
 'Trigger phrases are like examples you give a receptionist so they recognise different ways people might ask for the same service.',
 'Using only one or two obvious phrases; real users ask for the same thing in many different ways, so coverage needs variety.',
 ARRAY['power-virtual-agents','trigger-phrases','nlp','pl-900'], 'teacher_john', 'teacher_john'),

('concept_pl9_pvatopicauthor01', 'Bot Topic Authoring',
 'power platform',
 'Topic authoring is the process of designing a bot conversation with messages, questions, branches, and actions so the bot can guide users through a defined scenario.',
 'A refund-request topic asks for an order number, checks eligibility, explains the policy, and offers to create a support ticket.',
 'Topic authoring is like writing an interactive script where the next line changes depending on how the user responds.',
 'Designing conversations from the bot''s perspective instead of the user''s; the flow should feel natural to the person asking for help.',
 ARRAY['power-virtual-agents','topics','conversation-design','pl-900'], 'teacher_john', 'teacher_john'),

('concept_pl9_pvavariables01', 'Entities and Variables',
 'power platform',
 'Bots use entities and variables to capture important values from a conversation, such as names, dates, case numbers, and selections, so later steps can act on them.',
 'A support bot captures the user''s ticket number and preferred callback time, then passes those values into a Power Automate flow.',
 'Entities and variables are like note cards a receptionist fills in during a conversation so the right details are available when the task is handed off.',
 'Asking users for the same information multiple times because captured variables were not reused effectively across the conversation.',
 ARRAY['power-virtual-agents','variables','entities','pl-900'], 'teacher_john', 'teacher_john'),

('concept_pl9_pvasystemtopics01', 'System Topics',
 'power platform',
 'System topics are built-in bot behaviours for common conversational events such as greetings, escalation, fallback, and ending the conversation.',
 'When a user says "help" or the bot cannot understand the question, a system topic provides a fallback response and next-step options.',
 'System topics are like the house rules of a conversation — they make sure basic interactions work even when no custom topic is triggered.',
 'Ignoring system topics and customising only business topics; fallback and error conversations shape the user experience just as much as successful paths.',
 ARRAY['power-virtual-agents','system-topics','conversation','pl-900'], 'teacher_john', 'teacher_john'),

('concept_pl9_pvaflows01', 'Bot Integration with Power Automate',
 'power platform',
 'Virtual agents can call Power Automate flows to perform actions such as creating tickets, checking status, sending notifications, or updating records during a conversation.',
 'A facilities bot asks for a room number, calls a Power Automate flow to create a maintenance request, and returns the job reference instantly.',
 'Bot-to-flow integration is like giving the chatbot a back-office assistant — the bot speaks to the user while the flow does the operational work behind the scenes.',
 'Putting all business logic directly into the bot conversation when reusable backend steps should be handled in a flow.',
 ARRAY['power-virtual-agents','power-automate','integration','pl-900'], 'teacher_john', 'teacher_john'),

('concept_pl9_pvachannels01', 'Virtual Agent Publishing Channels',
 'power platform',
 'Bots can be published to channels such as websites, Microsoft Teams, and other messaging surfaces so users can access the same service in familiar places.',
 'An employee-help bot is published both to Teams and to the company intranet website, serving staff wherever they start the conversation.',
 'Publishing channels are like different service desks using the same knowledge base — the location changes, but the bot logic stays the same.',
 'Creating separate bots per channel when one shared bot would be easier to maintain and improve consistently.',
 ARRAY['power-virtual-agents','channels','publishing','pl-900'], 'teacher_john', 'teacher_john'),

('concept_pl9_pvaescalation01', 'Bot Escalation',
 'power platform',
 'When a virtual agent cannot resolve a request, it should escalate smoothly to a human or a manual process while preserving useful context from the conversation.',
 'A payroll bot escalates a complex tax question to HR, passing the user''s identity and the chat summary so the employee does not need to start over.',
 'Bot escalation is like a receptionist transferring a complicated case to a specialist while handing over the notes from the first conversation.',
 'Treating escalation as a failure instead of part of the service design; good bots are judged partly by how gracefully they hand off difficult cases.',
 ARRAY['power-virtual-agents','escalation','support','pl-900'], 'teacher_john', 'teacher_john'),

('concept_pl9_pvaanalytics01', 'Virtual Agent Analytics',
 'power platform',
 'Analytics help makers understand how often the bot is used, where conversations fail, which topics work well, and what should be improved next.',
 'Analytics show that many users abandon the refund topic after the second question, leading the team to simplify the wording and reduce drop-off.',
 'Bot analytics are like reviewing call-centre recordings and dashboards — they reveal where the service is efficient and where users get stuck.',
 'Looking only at total session count; conversation completion, escalation rate, and unresolved utterances often provide more actionable insight.',
 ARRAY['power-virtual-agents','analytics','improvement','pl-900'], 'teacher_john', 'teacher_john'),

('concept_pl9_pvaknowledge01', 'Knowledge Source Integration',
 'power platform',
 'Virtual agents can use connected documents, websites, or SharePoint content to answer common questions from trusted organisational knowledge sources.',
 'A HR bot connects to policy documents in SharePoint so employees can ask about parental leave and receive answers grounded in the official handbook.',
 'Knowledge source integration is like giving the bot access to the company handbook so it can answer routine questions without a human searching manually.',
 'Connecting outdated or contradictory content sources; the bot will reflect the quality and consistency of the underlying knowledge.',
 ARRAY['power-virtual-agents','knowledge','sharepoint','pl-900'], 'teacher_john', 'teacher_john'),

('concept_pl9_pvagenanswers01', 'Generative Answers',
 'power platform',
 'Generative answers allow a virtual agent to compose natural-language responses from connected knowledge rather than relying only on fully scripted conversation paths.',
 'Instead of a prewritten answer for every benefits question, the bot reads the benefits handbook and generates a contextual reply for the employee.',
 'Generative answers are like moving from a fixed FAQ card to a librarian who can read the source material and answer in natural language.',
 'Using generative answers without review or guardrails for sensitive scenarios such as legal advice, payroll disputes, or regulated customer guidance.',
 ARRAY['power-virtual-agents','generative-ai','knowledge','pl-900'], 'teacher_john', 'teacher_john'),

('concept_pl9_pvateams01', 'Virtual Agents in Microsoft Teams',
 'power platform',
 'Publishing bots into Microsoft Teams lets organisations deliver conversational help and lightweight automation inside the collaboration tool employees already use every day.',
 'A sales-support bot in Teams answers pricing-policy questions and launches a discount-approval workflow without users leaving the chat window.',
 'Bots in Teams are like adding a knowledgeable assistant directly into the team room instead of asking staff to visit a separate help website.',
 'Deploying the bot in Teams without adapting its wording and actions to the short, conversational style users expect in chat.',
 ARRAY['power-virtual-agents','teams','bot','pl-900'], 'teacher_john', 'teacher_john'),

('concept_pl9_pvausecases01', 'Virtual Agent Use Cases',
 'power platform',
 'Typical virtual agent scenarios include employee helpdesks, IT support, customer FAQs, order tracking, appointment booking, and triage for service requests.',
 'A healthcare provider uses a chatbot to answer clinic-hours questions, collect basic symptoms, and route patients to the right service channel.',
 'Virtual agent use cases are like repeatable front-desk conversations that happen so often they are worth standardising and automating.',
 'Starting with a broad "answer anything" bot instead of a focused high-volume use case where the team can measure improvement quickly.',
 ARRAY['power-virtual-agents','use-cases','chatbot','pl-900'], 'teacher_john', 'teacher_john'),

('concept_pl9_pvagovernance01', 'Virtual Agent Governance',
 'power platform',
 'Governance for virtual agents covers content ownership, escalation design, analytics review, identity and access, and approval processes for changes to production bots.',
 'A company requires HR to approve policy-answer updates, IT to review connected actions, and support leads to monitor unresolved bot questions weekly.',
 'Virtual agent governance is like editorial control for a public help desk — someone must own accuracy, tone, and the consequences of the bot''s answers.',
 'Allowing anyone to publish bot changes directly to production without review; inaccurate answers can spread quickly and damage trust.',
 ARRAY['power-virtual-agents','governance','chatbot','pl-900'], 'teacher_john', 'teacher_john'),

-- ── Group 7: Microsoft Cloud Ecosystem & Governance ──────────────────────────
('concept_pl9_mscloud01', 'Microsoft Cloud Ecosystem',
 'power platform',
 'The integrated set of Microsoft cloud services — Microsoft 365, Azure, Dynamics 365, and Power Platform — that share identity (Azure AD), data (Dataverse), and governance.',
 'A company uses Azure AD for identity, Microsoft 365 for productivity, Dynamics 365 for CRM, and Power Platform to build custom extensions — all governed from one tenant.',
 'The Microsoft Cloud is like a city built on one common infrastructure — roads (Azure), buildings (M365, D365), and custom extensions (Power Platform) all connect seamlessly.',
 'Treating each Microsoft cloud service as a standalone product; the strategic value comes from how they integrate, share data, and provide a unified governance model.',
 ARRAY['microsoft-cloud','ecosystem','integration','pl-900'], 'teacher_john', 'teacher_john'),

('concept_pl9_cdm01', 'Common Data Model (CDM)',
 'power platform',
 'A standardised, extensible collection of data schemas (Account, Contact, Product, Order) shared across Microsoft cloud services, enabling consistent data interpretation.',
 'The Account entity in Dynamics 365 CRM and the Account table in a custom Power Apps both use the same CDM schema, so data shared between them needs no translation.',
 'The Common Data Model is like a shared language for data — instead of each system speaking its own dialect, CDM gives every service the same vocabulary for common business entities.',
 'Ignoring CDM when designing custom tables; aligning custom schemas to CDM accelerates integration and makes data interoperable with Microsoft and third-party services.',
 ARRAY['cdm','data-model','interoperability','pl-900'], 'teacher_john', 'teacher_john'),

('concept_pl9_dvteams01', 'Dataverse for Teams',
 'power platform',
 'A lightweight version of Dataverse built into Microsoft Teams that lets users create simple apps and store data inside Teams without a full Power Platform licence.',
 'A team manager builds a simple meeting-action-tracker app inside Microsoft Teams using Dataverse for Teams — no additional licence needed beyond Microsoft 365.',
 'Dataverse for Teams is like a basic notebook built into Teams — enough for simple team-level apps, but you upgrade to full Dataverse when you need enterprise features.',
 'Assuming Dataverse for Teams has all the features of full Dataverse; it lacks advanced security roles, business rules, plugins, and large-scale capacity.',
 ARRAY['dataverse','teams','microsoft-365','pl-900'], 'teacher_john', 'teacher_john'),

('concept_pl9_security_bv01', 'Security and Compliance Value',
 'power platform',
 'Power Platform inherits Microsoft''s enterprise-grade security — Azure AD identity, role-based access, encryption at rest/transit, and compliance certifications (ISO, SOC, GDPR).',
 'A regulated financial firm adopts Power Platform knowing it meets FCA data residency requirements and integrates with their existing Azure AD conditional-access policies.',
 'Power Platform security is like renting office space in a Class A building — the core infrastructure (locks, fire systems, access control) is enterprise-grade from day one.',
 'Assuming platform-level security is sufficient without configuring app-level security roles and DLP policies; both layers are needed for a complete security posture.',
 ARRAY['security','compliance','governance','pl-900'], 'teacher_john', 'teacher_john'),

('concept_pl9_copilot_m365_01', 'Microsoft Copilot Integration',
 'power platform',
 'Microsoft Copilot (AI assistant powered by Azure OpenAI) is embedded across Microsoft 365, Dynamics 365, and Power Platform, enabling natural language interaction with business data.',
 'A sales manager asks Microsoft Copilot in Teams to summarise the last three customer calls and draft a follow-up email — Copilot pulls data from Dynamics 365 and M365.',
 'Microsoft Copilot is like a brilliant personal assistant who has read every document and email in your organisation and can find, summarise, and act on information instantly.',
 'Conflating Microsoft Copilot (M365 AI assistant) with Copilot Studio (bot-building platform); Copilot Studio is the tool for building custom copilots, not the AI assistant itself.',
 ARRAY['copilot','ai','microsoft-365','pl-900'], 'teacher_john', 'teacher_john'),

('concept_pl9_adoption01', 'Power Platform Adoption',
 'power platform',
 'The process of rolling out Power Platform across an organisation including training, community building (champions), governance setup, and demonstrating quick wins to build momentum.',
 'A company launches a Power Platform Centre of Excellence, trains 50 citizen developer champions, runs monthly hackathons, and tracks adoption via CoE Toolkit dashboards.',
 'Platform adoption is like planting a garden — you prepare the soil (governance), plant seeds (training and champions), water regularly (community and support), and harvest results (apps and automations).',
 'Deploying Power Platform without a structured adoption programme; without training, champions, and governance, the platform sees low usage or ungoverned sprawl.',
 ARRAY['adoption','governance','change-management','pl-900'], 'teacher_john', 'teacher_john'),

('concept_pl9_dlp_bv01', 'DLP Policy Business Value',
 'power platform',
 'Data Loss Prevention policies protect the organisation by preventing sensitive data from flowing to unauthorised external services via Power Apps or Power Automate connectors.',
 'A DLP policy blocks connectors that send data to consumer file-sharing services (Dropbox, Google Drive), ensuring corporate Dataverse data cannot be exfiltrated via flows.',
 'DLP policies are like a data customs officer — they inspect every flow''s connector connections and block packages from crossing the boundary to unapproved destinations.',
 'Setting DLP policies so restrictive that legitimate business automations are blocked, causing users to work around governance; balance security with productivity.',
 ARRAY['dlp','security','governance','pl-900'], 'teacher_john', 'teacher_john'),

('concept_pl9_sustainability01', 'Sustainability Value',
 'power platform',
 'Power Platform contributes to sustainability goals by replacing paper-based processes, reducing travel (digital approvals vs. in-person sign-offs), and running on Microsoft''s carbon-neutral cloud.',
 'Replacing 10,000 annual paper inspection forms with a Power Apps mobile solution eliminates paper waste and the associated printing, storage, and disposal costs.',
 'Digitalising processes on Power Platform is like switching from physical mail to email — the same information moves, but without the paper, printing, postage, and physical storage.',
 'Overstating sustainability impact without measurement; establish a baseline (paper used, travel taken) before digitalisation and measure actual reduction after.',
 ARRAY['sustainability','digital-transformation','business-value','pl-900'], 'teacher_john', 'teacher_john'),

('concept_pl9_community01', 'Power Platform Community',
 'power platform',
 'The global ecosystem of Power Platform users, MVPs, community forums, templates, and learning resources that accelerate skill development and problem-solving.',
 'A maker finds a community-built Power Apps template for project management on the Power Apps community gallery, saving two days of build time.',
 'The Power Platform community is like a global open-source library — millions of makers share templates, solutions, and answers so nobody has to solve the same problem twice.',
 'Not leveraging community resources before building from scratch; the Power Platform community gallery, Power Automate templates, and community forums resolve most common challenges.',
 ARRAY['community','learning','pl-900'], 'teacher_john', 'teacher_john')

ON CONFLICT (id) DO NOTHING;

-- ---------------------------------------------------------------------------
-- Topics (8, one per topic area)
-- ---------------------------------------------------------------------------

INSERT INTO topics (id, name, folder_id, description, created_by, updated_by)
VALUES
    ('topic_pl9_overview01', 'Power Platform Overview & Business Value',
     'folder_pl900_01',
     'The business case for Power Platform: low-code development, citizen developers, digital transformation, and integration with Microsoft 365, Azure, and Dynamics 365.',
     'teacher_john', 'teacher_john'),

    ('topic_pl9_foundation01', 'Foundational Components',
     'folder_pl900_01',
     'Core PL-900 building blocks: Dataverse, tables, relationships, connectors, Power Fx, app types, flows, solutions, environments, security, administration, and licensing basics.',
     'teacher_john', 'teacher_john'),

    ('topic_pl9_appsvalue01', 'Power Apps Business Value',
     'folder_pl900_01',
     'How Power Apps delivers value: app modernisation, mobile-first field apps, rapid development, fusion teams, AI Builder, governance, and Power Pages portals.',
     'teacher_john', 'teacher_john'),

    ('topic_pl9_autovalue01', 'Power Automate Business Value',
     'folder_pl900_01',
     'How Power Automate delivers value: cloud flows, flow types, connectors, approvals, conditions, desktop flows, monitoring, error reduction, and ROI measurement.',
     'teacher_john', 'teacher_john'),

    ('topic_pl9_bivalue01', 'Power BI Business Value',
     'folder_pl900_01',
     'How Power BI delivers value: self-service BI, Power Query, semantic models, reports and dashboards, security, alerts, mobile access, and governed sharing.',
     'teacher_john', 'teacher_john'),

    ('topic_pl9_copilotvalue01', 'Copilot Studio Business Value',
     'folder_pl900_01',
     'How Copilot Studio delivers value: chatbot automation, intent recognition, topics, actions, omnichannel deployment, live agent handoff, analytics, and generative AI.',
     'teacher_john', 'teacher_john'),

    ('topic_pl9_pagesbots01', 'Power Pages & Power Virtual Agents',
     'folder_pl900_01',
     'How Power Pages and Power Virtual Agents deliver value: external websites, self-service portals, Dataverse-backed security, bot topics, flow integration, analytics, and Teams/web publishing.',
     'teacher_john', 'teacher_john'),

    ('topic_pl9_ecosystem01', 'Microsoft Cloud Ecosystem & Governance',
     'folder_pl900_01',
     'The Microsoft Cloud platform: CDM, Dataverse for Teams, security and compliance, Microsoft Copilot, DLP policy value, adoption strategy, sustainability, and community.',
     'teacher_john', 'teacher_john')
ON CONFLICT (id) DO NOTHING;

-- ---------------------------------------------------------------------------
-- Topic ↔ Concept mappings (146 total)
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
    -- Foundational Components
    ('topic_pl9_foundation01', 'concept_pl9_found_dataverse01'),
    ('topic_pl9_foundation01', 'concept_pl9_found_tables01'),
    ('topic_pl9_foundation01', 'concept_pl9_found_relationships01'),
    ('topic_pl9_foundation01', 'concept_pl9_found_choices01'),
    ('topic_pl9_foundation01', 'concept_pl9_found_businessrules01'),
    ('topic_pl9_foundation01', 'concept_pl9_found_securityroles01'),
    ('topic_pl9_foundation01', 'concept_pl9_found_connectors01'),
    ('topic_pl9_foundation01', 'concept_pl9_found_customconnectors01'),
    ('topic_pl9_foundation01', 'concept_pl9_found_powerfx01'),
    ('topic_pl9_foundation01', 'concept_pl9_found_canvas01'),
    ('topic_pl9_foundation01', 'concept_pl9_found_modeldriven01'),
    ('topic_pl9_foundation01', 'concept_pl9_found_cloudflows01'),
    ('topic_pl9_foundation01', 'concept_pl9_found_desktopflows01'),
    ('topic_pl9_foundation01', 'concept_pl9_found_reports01'),
    ('topic_pl9_foundation01', 'concept_pl9_found_dashboards01'),
    ('topic_pl9_foundation01', 'concept_pl9_found_pagesites01'),
    ('topic_pl9_foundation01', 'concept_pl9_found_copilotstudio01'),
    ('topic_pl9_foundation01', 'concept_pl9_found_aibuilder01'),
    ('topic_pl9_foundation01', 'concept_pl9_found_environmentstrategy01'),
    ('topic_pl9_foundation01', 'concept_pl9_found_defaultenv01'),
    ('topic_pl9_foundation01', 'concept_pl9_found_solutions01'),
    ('topic_pl9_foundation01', 'concept_pl9_found_managed01'),
    ('topic_pl9_foundation01', 'concept_pl9_found_dlp01'),
    ('topic_pl9_foundation01', 'concept_pl9_found_admincenter01'),
    ('topic_pl9_foundation01', 'concept_pl9_found_makerportal01'),
    ('topic_pl9_foundation01', 'concept_pl9_found_templates01'),
    ('topic_pl9_foundation01', 'concept_pl9_found_licensing01'),
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
    ('topic_pl9_autovalue01', 'concept_pl9_cloudflow01'),
    ('topic_pl9_autovalue01', 'concept_pl9_automatedflow01'),
    ('topic_pl9_autovalue01', 'concept_pl9_instantflow01'),
    ('topic_pl9_autovalue01', 'concept_pl9_desktopflow01'),
    ('topic_pl9_autovalue01', 'concept_pl9_triggeraction01'),
    ('topic_pl9_autovalue01', 'concept_pl9_flowtemplate01'),
    ('topic_pl9_autovalue01', 'concept_pl9_stdpremium01'),
    ('topic_pl9_autovalue01', 'concept_pl9_approvalsconnector01'),
    ('topic_pl9_autovalue01', 'concept_pl9_condition01'),
    ('topic_pl9_autovalue01', 'concept_pl9_applytoeach01'),
    ('topic_pl9_autovalue01', 'concept_pl9_expression01'),
    ('topic_pl9_autovalue01', 'concept_pl9_runhistory01'),
    ('topic_pl9_autovalue01', 'concept_pl9_errorhandling01'),
    ('topic_pl9_autovalue01', 'concept_pl9_dataverseauto01'),
    ('topic_pl9_autovalue01', 'concept_pl9_mobileflow01'),
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
    ('topic_pl9_bivalue01', 'concept_pl9_semanticmodel01'),
    ('topic_pl9_bivalue01', 'concept_pl9_powerquery01'),
    ('topic_pl9_bivalue01', 'concept_pl9_datasource01'),
    ('topic_pl9_bivalue01', 'concept_pl9_visuals01'),
    ('topic_pl9_bivalue01', 'concept_pl9_kpi01'),
    ('topic_pl9_bivalue01', 'concept_pl9_slicers01'),
    ('topic_pl9_bivalue01', 'concept_pl9_drill01'),
    ('topic_pl9_bivalue01', 'concept_pl9_qna01'),
    ('topic_pl9_bivalue01', 'concept_pl9_alerts01'),
    ('topic_pl9_bivalue01', 'concept_pl9_rls01'),
    ('topic_pl9_bivalue01', 'concept_pl9_pbiapp01'),
    ('topic_pl9_bivalue01', 'concept_pl9_gateway01'),
    ('topic_pl9_bivalue01', 'concept_pl9_importdirect01'),
    ('topic_pl9_bivalue01', 'concept_pl9_dax01'),
    ('topic_pl9_bivalue01', 'concept_pl9_dataflow01'),
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
    -- Power Pages & Power Virtual Agents
    ('topic_pl9_pagesbots01', 'concept_pl9_pages01'),
    ('topic_pl9_pagesbots01', 'concept_pl9_pagesbiz01'),
    ('topic_pl9_pagesbots01', 'concept_pl9_pagesportal01'),
    ('topic_pl9_pagesbots01', 'concept_pl9_pagespartner01'),
    ('topic_pl9_pagesbots01', 'concept_pl9_pagestemplate01'),
    ('topic_pl9_pagesbots01', 'concept_pl9_pagesdesign01'),
    ('topic_pl9_pagesbots01', 'concept_pl9_pagesdataverse01'),
    ('topic_pl9_pagesbots01', 'concept_pl9_pagesauth01'),
    ('topic_pl9_pagesbots01', 'concept_pl9_pagesanon01'),
    ('topic_pl9_pagesbots01', 'concept_pl9_pageswebroles01'),
    ('topic_pl9_pagesbots01', 'concept_pl9_pagestableperm01'),
    ('topic_pl9_pagesbots01', 'concept_pl9_pagessecurity01'),
    ('topic_pl9_pagesbots01', 'concept_pl9_pagesformslists01'),
    ('topic_pl9_pagesbots01', 'concept_pl9_pagesusecase01'),
    ('topic_pl9_pagesbots01', 'concept_pl9_pva01'),
    ('topic_pl9_pagesbots01', 'concept_pl9_pvabiz01'),
    ('topic_pl9_pagesbots01', 'concept_pl9_pvatrigger01'),
    ('topic_pl9_pagesbots01', 'concept_pl9_pvatopicauthor01'),
    ('topic_pl9_pagesbots01', 'concept_pl9_pvavariables01'),
    ('topic_pl9_pagesbots01', 'concept_pl9_pvasystemtopics01'),
    ('topic_pl9_pagesbots01', 'concept_pl9_pvaflows01'),
    ('topic_pl9_pagesbots01', 'concept_pl9_pvachannels01'),
    ('topic_pl9_pagesbots01', 'concept_pl9_pvaescalation01'),
    ('topic_pl9_pagesbots01', 'concept_pl9_pvaanalytics01'),
    ('topic_pl9_pagesbots01', 'concept_pl9_pvaknowledge01'),
    ('topic_pl9_pagesbots01', 'concept_pl9_pvagenanswers01'),
    ('topic_pl9_pagesbots01', 'concept_pl9_pvateams01'),
    ('topic_pl9_pagesbots01', 'concept_pl9_pvausecases01'),
    ('topic_pl9_pagesbots01', 'concept_pl9_pvagovernance01'),
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

-- =============================================================================
-- Domains table + domain hierarchy for Power Platform
-- Hierarchy:
--   software
--   microsoft cloud  → software
--   power platform   → software, microsoft cloud
-- =============================================================================

CREATE TABLE IF NOT EXISTS domains (
    id           VARCHAR(64) PRIMARY KEY,
    name         VARCHAR(200) NOT NULL,
    description  TEXT NOT NULL DEFAULT '',
    created_by   VARCHAR(64) NOT NULL DEFAULT '',
    updated_by   VARCHAR(64) NOT NULL DEFAULT '',
    created_time TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_time TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT uq_domains_name UNIQUE (name)
);

CREATE TABLE IF NOT EXISTS domain_prerequisites (
    domain         VARCHAR(200) NOT NULL,
    prerequisite   VARCHAR(200) NOT NULL,
    created_by     VARCHAR(64) NOT NULL DEFAULT '',
    created_time   TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    PRIMARY KEY (domain, prerequisite)
);

-- ── 1. Domains ────────────────────────────────────────────────────────────────

INSERT INTO domains (id, name, description, created_by, updated_by) VALUES
  ('dom_software',      'software',        'The broad domain of software development, engineering practices, and programming paradigms.', 'seed', 'seed'),
  ('dom_mscloud',       'microsoft cloud', 'The integrated Microsoft cloud ecosystem — Azure, Microsoft 365, Dynamics 365, and Power Platform — built on shared identity, data, and APIs.', 'seed', 'seed'),
  ('dom_powerplatform', 'power platform',  'Microsoft''s suite of low-code tools — Power Apps, Power Automate, Power BI, and Copilot Studio — for building apps, automating processes, and analysing data.', 'seed', 'seed')
ON CONFLICT (name) DO NOTHING;

-- ── 2. Domain prerequisites ───────────────────────────────────────────────────

INSERT INTO domain_prerequisites (domain, prerequisite, created_by) VALUES
  ('microsoft cloud', 'software',        'seed'),
  ('power platform',  'software',        'seed'),
  ('power platform',  'microsoft cloud', 'seed')
ON CONFLICT DO NOTHING;

-- =============================================================================
-- Seed concepts for each domain
-- Power Platform has two parent domains:
--   1. microsoft cloud  — the broader Microsoft cloud ecosystem it belongs to
--   2. software         — the general low-code / application-development domain
-- =============================================================================

-- ---------------------------------------------------------------------------
-- Parent 1: Microsoft Cloud Platform  (domain: 'microsoft cloud')
-- ---------------------------------------------------------------------------

INSERT INTO concepts (id, canonical_name, domain, description, example,
analogy, common_mistakes, tags, created_by, updated_by)
VALUES

('concept_mscloud_overview01', 'Microsoft Cloud Platform',
 'microsoft cloud',
 'The integrated set of Microsoft cloud services — Azure, Microsoft 365, Dynamics 365, and Power Platform — that together deliver infrastructure, productivity, business applications, and low-code tooling on a shared identity and data foundation.',
 'An enterprise runs its infrastructure on Azure, collaborates in Microsoft 365, manages customers in Dynamics 365, and builds internal tools with Power Platform — all connected via Entra ID and Microsoft Dataverse.',
 'Microsoft Cloud is like a city district where every building (Azure, M365, D365, Power Platform) is connected by shared roads (identity, APIs, data) so residents can move seamlessly between them.',
 'Treating the Microsoft Cloud products as independent silos rather than recognising the shared Entra ID, Dataverse, and Connectors fabric that links them.',
 ARRAY['microsoft-cloud','azure','m365','dynamics365','power-platform','overview'], 'teacher_john', 'teacher_john'),

('concept_mscloud_entraid01', 'Microsoft Entra ID (Azure AD)',
 'microsoft cloud',
 'Microsoft''s cloud-based identity and access management service that provides single sign-on, MFA, conditional access, and app registrations for all Microsoft Cloud products and third-party SaaS.',
 'A user signs in once to Microsoft 365; the same Entra ID token is accepted by Power Platform, Azure, and registered enterprise apps without re-entering credentials.',
 'Entra ID is like a master key-card system for the whole Microsoft building — one card opens every door you are authorised to enter.',
 'Confusing Entra ID with on-premises Active Directory; Entra ID is cloud-native and synchronises with AD via Entra Connect, but they are not the same service.',
 ARRAY['entra-id','azure-ad','identity','sso','mfa','oauth','microsoft-cloud'], 'teacher_john', 'teacher_john'),

('concept_mscloud_m36501', 'Microsoft 365',
 'microsoft cloud',
 'The subscription suite of Microsoft cloud productivity services — Teams, SharePoint, Exchange Online, OneDrive, Outlook, and Copilot — built on Entra ID and tightly integrated with Power Platform.',
 'A Power Automate flow triggers from a new SharePoint list item (M365), creates a Dataverse record, sends a Teams notification, and emails the requester via Exchange Online — all within the Microsoft 365 and Power Platform ecosystem.',
 'Microsoft 365 is like the office floor of the Microsoft Cloud building — where knowledge workers spend most of their day, and where Power Platform tools plug in as productivity add-ons.',
 'Assuming Microsoft 365 and Office 365 are identical; M365 includes security (Defender, Purview), device management (Intune), and Copilot capabilities that O365 did not have.',
 ARRAY['microsoft-365','m365','teams','sharepoint','exchange','onedrive','microsoft-cloud'], 'teacher_john', 'teacher_john'),

('concept_mscloud_azure01', 'Microsoft Azure',
 'microsoft cloud',
 'Microsoft''s public cloud platform providing 200+ services across compute, storage, networking, AI, security, and data — the underlying infrastructure on which Power Platform, Dynamics 365, and Microsoft 365 are built.',
 'Power Platform uses Azure Service Bus for event streaming, Azure Key Vault for secret management, Azure API Management for custom connectors, and Azure Functions for serverless backend logic that Canvas Apps call via connectors.',
 'Azure is like the utility infrastructure (electricity, water, broadband) beneath the Microsoft Cloud city — most services run on it without tenants noticing, but developers can also provision Azure resources directly.',
 'Thinking Azure and Power Platform serve the same audience; Azure targets pro-code developers and infrastructure engineers while Power Platform targets makers and citizen developers, though both are used together in hybrid solutions.',
 ARRAY['azure','cloud-infrastructure','iaas','paas','faas','microsoft-cloud'], 'teacher_john', 'teacher_john'),

('concept_mscloud_dynamics01', 'Dynamics 365',
 'microsoft cloud',
 'Microsoft''s suite of intelligent business applications — Sales, Customer Service, Finance, Supply Chain, Field Service, and more — built on Dataverse, making them natively extensible with Power Platform tools.',
 'A sales team uses Dynamics 365 Sales for CRM; a Power Apps Model-Driven App adds a custom screen; a Power Automate flow automates quote approvals; a Power BI dashboard visualises pipeline — all reading the same Dataverse data.',
 'Dynamics 365 is like the pre-furnished apartments in the Microsoft Cloud building — move-in-ready business applications that tenants (businesses) can rearrange with Power Platform furniture.',
 'Treating Dynamics 365 and Power Platform as the same product; Dynamics 365 delivers packaged business processes while Power Platform provides the tooling to extend, automate, and connect them.',
 ARRAY['dynamics365','crm','erp','dataverse','microsoft-cloud'], 'teacher_john', 'teacher_john')

ON CONFLICT (id) DO NOTHING;

-- ---------------------------------------------------------------------------
-- Parent 2: Low-Code Development  (domain: 'software')
-- ---------------------------------------------------------------------------

INSERT INTO concepts (id, canonical_name, domain, description, example,
analogy, common_mistakes, tags, created_by, updated_by)
VALUES

('concept_sw_lowcode01', 'Low-Code Development',
 'software',
 'A software-development approach that uses visual designers, declarative configuration, and pre-built components to build applications with minimal hand-written code, making development accessible to non-professional developers.',
 'A business analyst builds a multi-step approval app in Power Apps using drag-and-drop forms and formula-based logic in Power Fx, without writing a single line of C# or JavaScript.',
 'Low-code development is like flat-pack furniture assembly — most of the hard manufacturing (infrastructure, UI framework, data connectors) is pre-built; you configure and connect pieces rather than crafting them from raw materials.',
 'Assuming low-code means no governance, no testing, or no architecture; production low-code solutions still require ALM, security design, performance testing, and maintainability practices.',
 ARRAY['low-code','no-code','citizen-developer','rapid-application-development','software'], 'teacher_john', 'teacher_john'),

('concept_sw_nocode01', 'No-Code Development',
 'software',
 'An extreme form of low-code where applications or automations are built entirely through visual configuration with zero programming, targeting business users with no technical background.',
 'A marketing manager uses Power Automate with pre-built templates to set up a Twitter-to-Teams notification flow by filling in a form — no expressions or formulas required.',
 'No-code is like a pre-programmed appliance — plug it in, press the right buttons, and it works; you cannot open it up and rewire it without leaving the no-code boundary.',
 'Confusing no-code with low-code; no-code is deliberately constrained for simplicity while low-code (e.g. Power Fx, custom connectors) allows controlled extensibility for more complex requirements.',
 ARRAY['no-code','citizen-developer','automation','software'], 'teacher_john', 'teacher_john'),

('concept_sw_rapidappdev01', 'Rapid Application Development (RAD)',
 'software',
 'A software development methodology that prioritises fast delivery through iterative prototyping, user feedback, and reusable components over lengthy upfront design and specification cycles.',
 'A Power Apps team delivers a working expense-submission prototype in two days, collects user feedback, and iterates to a production app in two weeks — far faster than a traditional waterfall project.',
 'RAD is like tailoring clothes on a live model — you fit and adjust repeatedly rather than designing a full pattern before cutting any fabric.',
 'Treating RAD as "no planning needed"; RAD still requires architecture decisions, data modelling, and security design — it just defers fine-grained UI specification in favour of working software.',
 ARRAY['rad','agile','iterative','software-development','software'], 'teacher_john', 'teacher_john'),

('concept_sw_citizendev01', 'Citizen Development (Platform)',
 'software',
 'An IT-governance strategy where organisations formally enable business users (citizen developers) to build their own solutions using approved low-code platforms, with guardrails such as DLP policies, CoE toolkits, and training programmes.',
 'A bank creates a citizen-developer programme: IT sets up Power Platform environments and DLP policies, HR runs a Power Apps training track, and business units build their own approved apps under IT review.',
 'Citizen development is like a managed community garden — the city (IT) provides the plots, tools, and rules; residents (business users) grow their own produce (apps) within defined boundaries.',
 'Equating citizen development with Shadow IT; a well-run citizen-development programme is IT-sanctioned, governed, and supported — the opposite of uncontrolled Shadow IT.',
 ARRAY['citizen-developer','governance','low-code','coe','software'], 'teacher_john', 'teacher_john'),

('concept_sw_fusiondev01', 'Fusion Development',
 'software',
 'A collaborative model where professional developers (pro-code) and citizen developers (low-code) work together on the same solution: pro-devs build reusable APIs, PCF controls, and custom connectors that makers consume in Power Platform.',
 'A pro-dev team publishes a secure Azure API Management endpoint and a PCF grid component; a citizen developer uses them as a custom connector and embedded control inside a Power Apps Canvas App.',
 'Fusion development is like a restaurant kitchen — professional chefs (pro-devs) prepare complex sauces and components; front-of-house staff (makers) assemble and serve the final dish (app) quickly.',
 'Assuming fusion development means pro-devs do all the real work and makers just click; the model is genuinely collaborative — makers own the user experience and business logic while pro-devs provide reusable foundations.',
 ARRAY['fusion-development','pro-code','low-code','pcf','custom-connector','software'], 'teacher_john', 'teacher_john')

ON CONFLICT (id) DO NOTHING;

-- ---------------------------------------------------------------------------
-- concept_relations — link Power Platform to its two parent domains
-- relation_type 'parent-domain' means concept_b_id is the broader domain
-- that contains / gave rise to concept_a_id
-- ---------------------------------------------------------------------------

INSERT INTO concept_relations (concept_a_id, concept_b_id, relation_type, created_by)
VALUES
    -- Power Platform IS-PART-OF Microsoft Cloud
    ('concept_pl9_pp01', 'concept_mscloud_overview01', 'parent-domain', 'teacher_john'),
    -- Power Platform IS-A Low-Code Development platform
    ('concept_pl9_pp01', 'concept_sw_lowcode01',        'parent-domain', 'teacher_john')
ON CONFLICT (concept_a_id, concept_b_id, relation_type) DO NOTHING;

-- =============================================================================
-- Anki Spaces + Flashcards for PL-400 concepts (one space per topic group)
-- Each concept gets at least one flashcard. Safe to re-run (ON CONFLICT DO NOTHING).
-- =============================================================================

-- ---------------------------------------------------------------------------
-- 10 Anki Spaces (one per topic group, under folder_powerplatform01)
-- ---------------------------------------------------------------------------

INSERT INTO spaces (id, folder_id, name, space_type, description, created_by, updated_by)
VALUES
    ('space_pp_dvfund01',    'folder_powerplatform01', 'Dataverse Fundamentals – Flashcards',       'Anki', 'Flashcards for Dataverse core concepts.',           'teacher_john', 'teacher_john'),
    ('space_pp_dvadv01',     'folder_powerplatform01', 'Dataverse Advanced Features – Flashcards',  'Anki', 'Flashcards for advanced Dataverse features.',       'teacher_john', 'teacher_john'),
    ('space_pp_powerapps01', 'folder_powerplatform01', 'Power Apps Development – Flashcards',       'Anki', 'Flashcards for Canvas and Model-Driven Apps.',      'teacher_john', 'teacher_john'),
    ('space_pp_pcfclient01', 'folder_powerplatform01', 'PCF and Client Scripting – Flashcards',     'Anki', 'Flashcards for PCF controls and client scripting.', 'teacher_john', 'teacher_john'),
    ('space_pp_autofund01',  'folder_powerplatform01', 'Power Automate Fundamentals – Flashcards',  'Anki', 'Flashcards for Cloud Flow core concepts.',           'teacher_john', 'teacher_john'),
    ('space_pp_bizauto01',   'folder_powerplatform01', 'Business Process Automation – Flashcards',  'Anki', 'Flashcards for BPF, business rules, and flow types.','teacher_john', 'teacher_john'),
    ('space_pp_plugindev01', 'folder_powerplatform01', 'Plugin Development – Flashcards',           'Anki', 'Flashcards for Dataverse plugin development.',       'teacher_john', 'teacher_john'),
    ('space_pp_intapi01',    'folder_powerplatform01', 'Integration and APIs – Flashcards',         'Anki', 'Flashcards for Web API, connectors, and integration.','teacher_john', 'teacher_john'),
    ('space_pp_alm01',       'folder_powerplatform01', 'ALM and DevOps – Flashcards',               'Anki', 'Flashcards for ALM, pipelines, and environment management.','teacher_john','teacher_john'),
    ('space_pp_secgov01',    'folder_powerplatform01', 'Security and Governance – Flashcards',      'Anki', 'Flashcards for DLP, admin, licensing, and security.','teacher_john', 'teacher_john')
ON CONFLICT (id) DO NOTHING;

-- ---------------------------------------------------------------------------
-- Flashcards — Group 1: Dataverse Fundamentals (space_pp_dvfund01)
-- ---------------------------------------------------------------------------

INSERT INTO flash_cards (id, space_id, front, back, created_by, updated_by) VALUES

('fc_pp_dataverse01',   'space_pp_dvfund01',
 'What is Microsoft Dataverse?',
 'A cloud-based data storage platform built into Power Platform that securely stores and manages business data, providing a built-in API, security model, and auditing — similar to SQL Server but managed.',
 'teacher_john', 'teacher_john'),

('fc_pp_table01',       'space_pp_dvfund01',
 'What is a Dataverse Table (formerly called what)?',
 'A structured container of rows and columns in Dataverse equivalent to a database table. Formerly called an Entity.',
 'teacher_john', 'teacher_john'),

('fc_pp_columntype01',  'space_pp_dvfund01',
 'Name four column data types available in Dataverse.',
 'Text, Number (including Currency), Date/Time, Choice (Option Set), Lookup, File, and Image.',
 'teacher_john', 'teacher_john'),

('fc_pp_onetomany01',   'space_pp_dvfund01',
 'In a Dataverse One-to-Many relationship, which table holds the Lookup column?',
 'The child (many) table holds the Lookup column that points back to the parent (one) table.',
 'teacher_john', 'teacher_john'),

('fc_pp_manytomany01',  'space_pp_dvfund01',
 'What backs a native Many-to-Many relationship in Dataverse?',
 'An intersect table automatically created by Dataverse to store the association between the two tables.',
 'teacher_john', 'teacher_john'),

('fc_pp_solution01',    'space_pp_dvfund01',
 'What is a Power Platform Solution?',
 'A container that packages customizations (tables, flows, apps, security roles) so they can be transported across environments as a single unit.',
 'teacher_john', 'teacher_john'),

('fc_pp_publisher01',   'space_pp_dvfund01',
 'What does the Solution Publisher define?',
 'The customization prefix (e.g. "contoso_") applied to all solution components, identifying the vendor and preventing naming collisions.',
 'teacher_john', 'teacher_john'),

('fc_pp_managed01',     'space_pp_dvfund01',
 'What is the key difference between a Managed and an Unmanaged solution?',
 'Managed solutions are locked distributable packages used in UAT/Production. Unmanaged solutions allow direct editing and are used during development.',
 'teacher_john', 'teacher_john'),

('fc_pp_securityrole01','space_pp_dvfund01',
 'What does a Dataverse Security Role define?',
 'A set of privileges specifying what CRUD operations a user can perform on each table, at what scope (user, business unit, organization).',
 'teacher_john', 'teacher_john'),

('fc_pp_businessunit01','space_pp_dvfund01',
 'What is the purpose of a Business Unit in Dataverse?',
 'A hierarchical organizational unit that groups users to control data access scope — users in the same BU share data access governed by security roles.',
 'teacher_john', 'teacher_john'),

-- ---------------------------------------------------------------------------
-- Group 2: Dataverse Advanced Features (space_pp_dvadv01)
-- ---------------------------------------------------------------------------

('fc_pp_calculated01',  'space_pp_dvadv01',
 'What is a Calculated Column in Dataverse?',
 'A column whose value is automatically computed from a formula referencing other columns in the same row, like a formula cell in Excel.',
 'teacher_john', 'teacher_john'),

('fc_pp_rollup01',      'space_pp_dvadv01',
 'How does a Rollup Column differ from a Calculated Column?',
 'A Rollup Column aggregates (sum/count/min/max/avg) values from related child rows on a scheduled basis (~every 12 hours), not in real time.',
 'teacher_john', 'teacher_john'),

('fc_pp_altkey01',      'space_pp_dvadv01',
 'What is an Alternate Key used for in Dataverse?',
 'To uniquely identify a row using a meaningful column (e.g. OrderNumber) instead of the primary GUID, enabling upsert operations via the Web API.',
 'teacher_john', 'teacher_john'),

('fc_pp_elastictable01','space_pp_dvadv01',
 'What underlying technology powers Dataverse Elastic Tables, and what are they designed for?',
 'Azure Cosmos DB. Elastic Tables are designed for high-volume, high-velocity data with flexible schemas — e.g. IoT telemetry. They do not support plugins.',
 'teacher_john', 'teacher_john'),

('fc_pp_auditlog01',    'space_pp_dvadv01',
 'What does enabling Dataverse Audit capture?',
 'Who created, modified, or deleted a record and when, including old and new field values, for compliance and troubleshooting.',
 'teacher_john', 'teacher_john'),

('fc_pp_dvsearch01',    'space_pp_dvadv01',
 'How does Dataverse Search differ from Quick Find?',
 'Dataverse Search is a full-text, relevance-based search across multiple tables powered by Azure Cognitive Search. Quick Find searches a single table by keyword.',
 'teacher_john', 'teacher_john'),

('fc_pp_virtualcol01',  'space_pp_dvadv01',
 'What is a Virtual Column in Dataverse and what limitation does it have?',
 'A column that retrieves its value from an external data source at query time without storing data. It cannot be filtered or sorted server-side.',
 'teacher_john', 'teacher_john'),

('fc_pp_choice01',      'space_pp_dvadv01',
 'In a Dataverse Choice column, what is stored in the database versus what the user sees?',
 'An integer value is stored in the database. The UI displays the corresponding text label defined in the choice list.',
 'teacher_john', 'teacher_john'),

('fc_pp_polylookup01',  'space_pp_dvadv01',
 'What makes a Lookup column "polymorphic"?',
 'It can reference rows from more than one table type — for example, the Regarding column on Activities can point to Account, Contact, or Lead.',
 'teacher_john', 'teacher_john'),

('fc_pp_tableperm01',   'space_pp_dvadv01',
 'What are Table Permissions in Power Pages and what scope controls access to only the current user''s own records?',
 'Table Permissions control which Dataverse records website users can access. "Self" scope grants access only to the user''s own record.',
 'teacher_john', 'teacher_john'),

-- ---------------------------------------------------------------------------
-- Group 3: Power Apps Development (space_pp_powerapps01)
-- ---------------------------------------------------------------------------

('fc_pp_canvasapp01',   'space_pp_powerapps01',
 'What distinguishes a Canvas App from a Model-Driven App?',
 'A Canvas App gives full control over UI layout and logic using Power Fx formulas. A Model-Driven App auto-generates UI from Dataverse metadata.',
 'teacher_john', 'teacher_john'),

('fc_pp_mdapp01',       'space_pp_powerapps01',
 'What drives the layout of a Model-Driven App?',
 'Dataverse metadata — the app automatically renders forms, views, charts, and dashboards based on the tables and columns configured.',
 'teacher_john', 'teacher_john'),

('fc_pp_powerfx01',     'space_pp_powerapps01',
 'What is Power Fx and what language inspired it?',
 'Power Fx is the low-code formula language used in Canvas Apps for logic, data operations, and navigation. It is inspired by Excel formulas.',
 'teacher_john', 'teacher_john'),

('fc_pp_connector01',   'space_pp_powerapps01',
 'What is a Power Platform Connector?',
 'A proxy wrapper around an external API that standardises how Power Apps and Power Automate communicate with services like SharePoint, SQL, or custom APIs.',
 'teacher_john', 'teacher_john'),

('fc_pp_delegation01',  'space_pp_powerapps01',
 'What problem does Delegation solve in Canvas Apps?',
 'It pushes query processing to the data source server-side, avoiding the 500/2000-row local limit by only returning matching records.',
 'teacher_john', 'teacher_john'),

('fc_pp_collection01',  'space_pp_powerapps01',
 'What is a Canvas App Collection and how is it created?',
 'An in-memory local table for caching or staging data within the app session, created with Collect() or ClearCollect(). It is cleared when the app closes.',
 'teacher_john', 'teacher_john'),

('fc_pp_gallery01',     'space_pp_powerapps01',
 'What does a Gallery control display and how is it structured?',
 'A scrollable list of records from a data source. All items share the same repeating template — you design the template once and data fills in automatically.',
 'teacher_john', 'teacher_john'),

('fc_pp_appform01',     'space_pp_powerapps01',
 'Which function saves data from a Form control to Dataverse, and which resets it afterwards?',
 'SubmitForm() saves the data. ResetForm() clears the form after a successful submit.',
 'teacher_john', 'teacher_john'),

('fc_pp_custompage01',  'space_pp_powerapps01',
 'What is a Custom Page in Power Apps?',
 'A Canvas App page embedded inside a Model-Driven App, enabling rich custom UI while retaining access to the MDA navigation and Dataverse context.',
 'teacher_john', 'teacher_john'),

('fc_pp_appdesigner01', 'space_pp_powerapps01',
 'What does the App Designer configure in a Model-Driven App?',
 'The navigation sitemap, which tables/forms/views/dashboards are included, and how users move between them.',
 'teacher_john', 'teacher_john'),

-- ---------------------------------------------------------------------------
-- Group 4: PCF and Client Scripting (space_pp_pcfclient01)
-- ---------------------------------------------------------------------------

('fc_pp_pcf01',         'space_pp_pcfclient01',
 'What is the Power Apps Component Framework (PCF)?',
 'A framework for building reusable code components in TypeScript that run inside Canvas or Model-Driven Apps, replacing default field renderings with custom HTML/CSS/JS.',
 'teacher_john', 'teacher_john'),

('fc_pp_typescript01',  'space_pp_pcfclient01',
 'What are the three lifecycle methods of a PCF control?',
 'init() — called once on load; updateView() — called when bound data or app state changes; destroy() — called on cleanup.',
 'teacher_john', 'teacher_john'),

('fc_pp_reactpcf01',    'space_pp_pcfclient01',
 'What is the advantage of a React Virtual PCF control over a Standard PCF control?',
 'It renders inside the shared Power Apps React root rather than spinning up its own, avoiding multiple conflicting React instances per page.',
 'teacher_john', 'teacher_john'),

('fc_pp_pcfmanifest01', 'space_pp_pcfclient01',
 'What is the PCF manifest file and what does it declare?',
 'ControlManifest.Input.xml — it declares the component''s properties (inputs), resources (JS/CSS), and feature usage to the Power Apps runtime.',
 'teacher_john', 'teacher_john'),

('fc_pp_xrm01',         'space_pp_pcfclient01',
 'What JavaScript object provides programmatic access to Model-Driven App forms?',
 'window.Xrm (the Client API). Use formContext.getAttribute(), formContext.ui.tabs.get(), etc. Never use direct DOM access.',
 'teacher_john', 'teacher_john'),

('fc_pp_formevent01',   'space_pp_pcfclient01',
 'What are the three Model-Driven App form lifecycle events?',
 'OnLoad (form opens), OnSave (user saves the record), OnChange (a field value changes).',
 'teacher_john', 'teacher_john'),

('fc_pp_fieldevent01',  'space_pp_pcfclient01',
 'What fires the OnChange event on a form field, and what common mistake causes an infinite loop?',
 'The user changing the field value fires OnChange. Setting that same field''s value in code inside its own handler causes an infinite loop — pass fireOnChange: false.',
 'teacher_john', 'teacher_john'),

('fc_pp_jswebres01',    'space_pp_pcfclient01',
 'What is a JavaScript Web Resource in Dataverse?',
 'A .js file stored in Dataverse that is loaded by Model-Driven App forms for event handler logic. Must use a namespace to avoid naming collisions.',
 'teacher_john', 'teacher_john'),

('fc_pp_htmlwebres01',  'space_pp_pcfclient01',
 'How is an HTML Web Resource surfaced inside a Model-Driven App form?',
 'As an iframe inside the form. To access the parent form''s context from inside the iframe, use the getContentWindow API.',
 'teacher_john', 'teacher_john'),

('fc_pp_commandbar01',  'space_pp_pcfclient01',
 'What tool is recommended for modern command bar customization in Model-Driven Apps?',
 'The Command Designer in the Power Apps maker portal. Use the legacy Ribbon Workbench only when Command Designer does not support the requirement.',
 'teacher_john', 'teacher_john'),

-- ---------------------------------------------------------------------------
-- Group 5: Power Automate Fundamentals (space_pp_autofund01)
-- ---------------------------------------------------------------------------

('fc_pp_cloudflow01',   'space_pp_autofund01',
 'What is a Cloud Flow in Power Automate?',
 'An automation that runs in the cloud, connecting services via triggers and actions without requiring local infrastructure.',
 'teacher_john', 'teacher_john'),

('fc_pp_flowtrigger01', 'space_pp_autofund01',
 'What is a Flow Trigger and give one example?',
 'The event that starts a Cloud Flow. Example: "When a Dataverse row is added, modified or deleted" fires when a new Opportunity is created.',
 'teacher_john', 'teacher_john'),

('fc_pp_flowaction01',  'space_pp_autofund01',
 'What is a Flow Action?',
 'A unit of work in a Cloud Flow that performs one operation, such as sending an email, updating a Dataverse row, or calling an HTTP endpoint.',
 'teacher_john', 'teacher_john'),

('fc_pp_condition01',   'space_pp_autofund01',
 'What does a Condition action do in a Cloud Flow?',
 'It branches execution into "If yes" and "If no" paths based on a boolean expression. Use Switch for multiple discrete values instead of nested Conditions.',
 'teacher_john', 'teacher_john'),

('fc_pp_applytoeach01', 'space_pp_autofund01',
 'What does the Apply to Each control do in Power Automate?',
 'It iterates over every item in an array, executing the nested actions once for each element — equivalent to a for-each loop.',
 'teacher_john', 'teacher_john'),

('fc_pp_errorhandling01','space_pp_autofund01',
 'How do you implement try/catch error handling in a Cloud Flow?',
 'Wrap critical steps in a Scope action. Add a parallel branch with "Configure run after" set to "has failed" to catch and handle errors.',
 'teacher_john', 'teacher_john'),

('fc_pp_envvar01',      'space_pp_autofund01',
 'What is an Environment Variable in Power Platform and why use it?',
 'A solution component that stores configuration values (strings, numbers, secrets) separately from flow logic, enabling environment-specific settings without editing flows.',
 'teacher_john', 'teacher_john'),

('fc_pp_connref01',     'space_pp_autofund01',
 'What is a Connection Reference and what problem does it solve?',
 'A solution component that abstracts the connector credentials from the flow, allowing credentials to be swapped per environment without editing the flow.',
 'teacher_john', 'teacher_john'),

('fc_pp_approval01',    'space_pp_autofund01',
 'What connector powers Approval Flows and what happens when an approval times out?',
 'The Approvals connector. Approvals time out after 30 days by default if the approver does not respond.',
 'teacher_john', 'teacher_john'),

('fc_pp_childflow01',   'space_pp_autofund01',
 'What is a Child Flow and what is its main benefit?',
 'A Cloud Flow called from other flows using "Run a Child Flow", enabling reusable logic shared across multiple parent flows — like a function in programming.',
 'teacher_john', 'teacher_john'),

-- ---------------------------------------------------------------------------
-- Group 6: Business Process Automation (space_pp_bizauto01)
-- ---------------------------------------------------------------------------

('fc_pp_bpf01',         'space_pp_bizauto01',
 'What is a Business Process Flow (BPF)?',
 'A stage-based guided process overlay in Model-Driven Apps that walks users through required steps, preventing them from skipping stages.',
 'teacher_john', 'teacher_john'),

('fc_pp_bpfstage01',    'space_pp_bizauto01',
 'What is a BPF Stage and what must happen before a user can advance?',
 'A named phase containing required data steps (fields). The user must complete all required fields in the current stage before moving to the next.',
 'teacher_john', 'teacher_john'),

('fc_pp_bizrule01',     'space_pp_bizauto01',
 'What can a Dataverse Business Rule do, and what can it NOT do?',
 'It can set field visibility, requirements, and default values on forms and server-side. It cannot operate on related table rows — only the current row.',
 'teacher_john', 'teacher_john'),

('fc_pp_custaction01',  'space_pp_bizauto01',
 'What is a Custom Process Action in Dataverse?',
 'A reusable named Dataverse operation (like a stored procedure) with defined inputs/outputs, callable from flows, plugins, or client scripts.',
 'teacher_john', 'teacher_john'),

('fc_pp_customapi01',   'space_pp_bizauto01',
 'How does a Custom API differ from a Custom Process Action?',
 'A Custom API exposes a typed Web API message backed by a plugin with request/response parameters. It is the modern preferred approach over Custom Process Actions.',
 'teacher_john', 'teacher_john'),

('fc_pp_scheduledflow01','space_pp_bizauto01',
 'What triggers a Scheduled Flow?',
 'A recurring time-based schedule (e.g. every day at 2 AM), like a cron job — not an event.',
 'teacher_john', 'teacher_john'),

('fc_pp_automatedflow01','space_pp_bizauto01',
 'What triggers an Automated Flow?',
 'An event in a connected service, such as a new Dataverse row creation or an incoming email — it runs reactively without user interaction.',
 'teacher_john', 'teacher_john'),

('fc_pp_instantflow01', 'space_pp_bizauto01',
 'How is an Instant Flow started?',
 'Manually by a user — via a button in Power Automate, a Canvas App button, or a Teams message action.',
 'teacher_john', 'teacher_john'),

('fc_pp_desktopflow01', 'space_pp_bizauto01',
 'What is a Desktop Flow (RPA) and when should you use it?',
 'A Power Automate automation that controls desktop or legacy applications via UI interaction. Use it only as a last resort when no API is available.',
 'teacher_john', 'teacher_john'),

('fc_pp_classicwf01',   'space_pp_bizauto01',
 'What is a Classic Workflow in Dataverse and what is the recommended migration path?',
 'A legacy background/real-time automation predating Power Automate. New automations should use Cloud Flows; existing Classic Workflows should be migrated.',
 'teacher_john', 'teacher_john'),

-- ---------------------------------------------------------------------------
-- Group 7: Plugin Development (space_pp_plugindev01)
-- ---------------------------------------------------------------------------

('fc_pp_plugin01',      'space_pp_plugindev01',
 'What is a Dataverse Plugin?',
 'A .NET assembly with event-handler classes that execute synchronously or asynchronously when a Dataverse data operation (Create, Update, Delete, etc.) occurs.',
 'teacher_john', 'teacher_john'),

('fc_pp_pluginstep01',  'space_pp_plugindev01',
 'What does a Plugin Step registration define?',
 'The message (e.g. Create), table, pipeline stage (Pre/Post-Operation), and optional attribute filter that determine when the plugin class executes.',
 'teacher_john', 'teacher_john'),

('fc_pp_pluginimage01', 'space_pp_plugindev01',
 'What is a Pre-Image vs a Post-Image in a Plugin?',
 'Pre-Image: snapshot of the row before the operation. Post-Image: snapshot after. Pre-Images do not exist on Create steps; Post-Images do not exist on Delete steps.',
 'teacher_john', 'teacher_john'),

('fc_pp_iorgservice01', 'space_pp_plugindev01',
 'What is IOrganizationService used for in a plugin?',
 'The primary SDK interface for performing CRUD, queries, and custom messages against Dataverse from within plugin or custom code.',
 'teacher_john', 'teacher_john'),

('fc_pp_ipluginctx01',  'space_pp_plugindev01',
 'What information does IPluginExecutionContext provide?',
 'Triggering event details: input/output parameters (e.g. the Target entity), pre/post images, the triggering user ID, depth, and business unit context.',
 'teacher_john', 'teacher_john'),

('fc_pp_svccontext01',  'space_pp_plugindev01',
 'What does OrganizationServiceContext add over IOrganizationService?',
 'LINQ query support and identity-mapped change tracking (like Entity Framework), enabling strongly-typed queries with .Where() and .ToList().',
 'teacher_john', 'teacher_john'),

('fc_pp_virtualtable01','space_pp_plugindev01',
 'What is a Virtual Table Provider?',
 'A plugin that handles Retrieve/RetrieveMultiple for a virtual table, fetching data live from an external source and surfacing it as a standard Dataverse table.',
 'teacher_john', 'teacher_john'),

('fc_pp_asyncplugin01', 'space_pp_plugindev01',
 'When does an Asynchronous Plugin execute relative to the Dataverse transaction?',
 'After the transaction commits, via the Async Service — it does not block the user''s save operation. Use it for non-time-critical background work.',
 'teacher_john', 'teacher_john'),

('fc_pp_plugintrace01', 'space_pp_plugindev01',
 'How do you write diagnostic messages from a plugin and where can you read them?',
 'Use ITracingService.Trace(). Messages are written to the Plugin Trace Log table, readable in the maker portal when tracing is enabled.',
 'teacher_john', 'teacher_john'),

('fc_pp_sandbox01',     'space_pp_plugindev01',
 'What restrictions does Plugin Sandbox Mode impose?',
 'No file system, registry, or arbitrary network access. Plugins can only call Dataverse via IOrganizationService or explicitly allowed HTTP endpoints.',
 'teacher_john', 'teacher_john'),

-- ---------------------------------------------------------------------------
-- Group 8: Integration and APIs (space_pp_intapi01)
-- ---------------------------------------------------------------------------

('fc_pp_webapi01',      'space_pp_intapi01',
 'What standard does the Dataverse Web API follow?',
 'OData v4. It provides RESTful CRUD, query, and custom message access — any HTTP client can read/write Dataverse data.',
 'teacher_john', 'teacher_john'),

('fc_pp_odata01',       'space_pp_intapi01',
 'Match these OData query options to their SQL equivalents: $filter, $select, $orderby, $top.',
 '$filter = WHERE, $select = SELECT, $orderby = ORDER BY, $top = LIMIT.',
 'teacher_john', 'teacher_john'),

('fc_pp_customconn01',  'space_pp_intapi01',
 'What is a Custom Connector in Power Platform?',
 'A user-defined connector built from an OpenAPI definition that wraps any HTTP API for use in Canvas Apps and flows like a built-in connector.',
 'teacher_john', 'teacher_john'),

('fc_pp_openapi01',     'space_pp_intapi01',
 'What OpenAPI version do Custom Connectors require?',
 'OpenAPI 2.0 (Swagger). OpenAPI 3.0 is not supported for Custom Connectors.',
 'teacher_john', 'teacher_john'),

('fc_pp_webhook01',     'space_pp_intapi01',
 'How does a Dataverse Webhook notify an external system?',
 'It sends an HTTP POST with the ExecutionContext payload to a registered external URL whenever the configured Dataverse event fires.',
 'teacher_john', 'teacher_john'),

('fc_pp_svcendpoint01', 'space_pp_intapi01',
 'What is a Dataverse Service Endpoint?',
 'A configuration that routes event messages to an Azure Service Bus queue/topic, Azure Event Hub, or Webhook target for external integration.',
 'teacher_john', 'teacher_john'),

('fc_pp_servicebus01',  'space_pp_intapi01',
 'What integration pattern does Azure Service Bus provide for Dataverse?',
 'Decoupled async messaging — Dataverse posts event context to a queue/topic and the consumer processes messages at its own pace.',
 'teacher_john', 'teacher_john'),

('fc_pp_oauth201',      'space_pp_intapi01',
 'Which OAuth 2.0 flow is used when a user signs in interactively to a Custom Connector?',
 'Authorization Code flow — the user authenticates once and the connector stores the resulting access token for subsequent API calls.',
 'teacher_john', 'teacher_john'),

('fc_pp_powerbi01',     'space_pp_intapi01',
 'How is Power BI surfaced inside a Model-Driven App?',
 'Via Power BI Embedded — reports and dashboards are embedded in MDA system dashboards or forms, providing in-context analytics.',
 'teacher_john', 'teacher_john'),

('fc_pp_powerpages01',  'space_pp_intapi01',
 'What security mechanism controls which Dataverse records external Power Pages users can access?',
 'Table Permissions — without them all Dataverse data is inaccessible to portal users by default.',
 'teacher_john', 'teacher_john'),

-- ---------------------------------------------------------------------------
-- Group 9: ALM and DevOps (space_pp_alm01)
-- ---------------------------------------------------------------------------

('fc_pp_alm01',         'space_pp_alm01',
 'What is Power Platform ALM and what is the typical environment promotion order?',
 'Managing solutions across environments with automated pipelines and source control. Typical order: Development → Test/Sandbox → Production.',
 'teacher_john', 'teacher_john'),

('fc_pp_solchecker01',  'space_pp_alm01',
 'What does Solution Checker do?',
 'Performs static analysis of solution components to identify performance, reliability, and upgrade issues — like a linter for Power Platform.',
 'teacher_john', 'teacher_john'),

('fc_pp_ppcli01',       'space_pp_alm01',
 'What command exports a solution using the Power Platform CLI?',
 'pac solution export --name <SolutionName> --path ./solutions',
 'teacher_john', 'teacher_john'),

('fc_pp_azdevops01',    'space_pp_alm01',
 'What Azure DevOps extension enables Power Platform pipeline tasks?',
 'Power Platform Build Tools — provides tasks for export, import, publish, check, and environment management.',
 'teacher_john', 'teacher_john'),

('fc_pp_ghactions01',   'space_pp_alm01',
 'Which GitHub Actions repository provides official Power Platform actions?',
 'microsoft/powerplatform-actions — includes export-solution, import-solution, publish-solution, and environment management actions.',
 'teacher_john', 'teacher_john'),

('fc_pp_envstrategy01', 'space_pp_alm01',
 'What is a minimal environment strategy for a small Power Platform team?',
 'Developer Sandbox → Shared Test → Production. Each stage uses managed solutions promoted by automated pipelines.',
 'teacher_john', 'teacher_john'),

('fc_pp_managedenv01',  'space_pp_alm01',
 'What is a Managed Environment and name two features it enables?',
 'A premium Power Platform feature providing enhanced governance. Features include: weekly digest, Solution Checker enforcement on import, and sharing limits.',
 'teacher_john', 'teacher_john'),

('fc_pp_sollayers01',   'space_pp_alm01',
 'What are Solution Layers in Dataverse?',
 'Stacked customizations where each solution adds a layer on a component. The top (active) layer wins — like CSS specificity for Dataverse components.',
 'teacher_john', 'teacher_john'),

('fc_pp_depcheck01',    'space_pp_alm01',
 'What does the Dependency Checker help prevent?',
 'Accidental deletion of components that other solution components depend on — it shows all places that reference a given component before you remove it.',
 'teacher_john', 'teacher_john'),

('fc_pp_fieldsecp01',   'space_pp_alm01',
 'What is a Field Security Profile in Dataverse?',
 'A security construct that restricts read/create/update access to specific sensitive columns, independently of the table-level security role.',
 'teacher_john', 'teacher_john'),

-- ---------------------------------------------------------------------------
-- Group 10: Security and Governance (space_pp_secgov01)
-- ---------------------------------------------------------------------------

('fc_pp_dlp01',         'space_pp_secgov01',
 'What is a DLP Policy in Power Platform?',
 'An admin policy that classifies connectors into Business, Non-Business, or Blocked tiers to prevent flows from combining incompatible data sources.',
 'teacher_john', 'teacher_john'),

('fc_pp_admincenter01', 'space_pp_secgov01',
 'What is managed from the Power Platform Admin Center?',
 'Environments, capacity, DLP policies, connector management, and tenant-level analytics across the entire Power Platform tenant.',
 'teacher_john', 'teacher_john'),

('fc_pp_coe01',         'space_pp_secgov01',
 'What is the CoE Toolkit and what is it not?',
 'A reference implementation of governance tooling (Power BI dashboard, flows, apps) for tenant visibility and standards enforcement. It is not a finished product — it requires customization.',
 'teacher_john', 'teacher_john'),

('fc_pp_tenantanalytics01','space_pp_secgov01',
 'What does Tenant-level Analytics in Admin Center show?',
 'Usage metrics across all environments: active users, flow run counts, connector usage, and app launches. Data has up to a 28-day lag.',
 'teacher_john', 'teacher_john'),

('fc_pp_managedid01',   'space_pp_secgov01',
 'What is a Managed Identity and why is it preferred over client secrets?',
 'An Azure-managed identity (system or user-assigned) that authenticates services without stored credentials. Preferred because it never expires and does not require secret rotation.',
 'teacher_john', 'teacher_john'),

('fc_pp_apilimit01',    'space_pp_secgov01',
 'What happens when a Power Platform user exceeds their daily API request limit?',
 'Performance is throttled or requests are blocked. High-volume workloads require capacity add-ons beyond the per-user daily allocation.',
 'teacher_john', 'teacher_john'),

('fc_pp_licensing01',   'space_pp_secgov01',
 'Can a Microsoft 365 license user use premium Dataverse connectors in Power Apps?',
 'No. Premium connectors and Dataverse require a Power Apps per-user or per-app plan. Microsoft 365 only covers standard connectors.',
 'teacher_john', 'teacher_john'),

('fc_pp_dvteam01',      'space_pp_secgov01',
 'What types of Dataverse Teams exist and what is an AAD Group Team?',
 'Owner, Access, and AAD Group teams. An AAD Group Team maps an Azure AD group to a Dataverse team — group membership automatically grants the assigned security roles.',
 'teacher_john', 'teacher_john'),

('fc_pp_hierarchysec01','space_pp_secgov01',
 'What two hierarchy models does Dataverse Hierarchy Security support?',
 'Manager hierarchy (based on the Manager field on users) and Position hierarchy (based on a Position table). Both grant managers access to reports'' records.',
 'teacher_john', 'teacher_john'),

('fc_pp_pad01',         'space_pp_secgov01',
 'What is Power Automate Desktop (PAD) and what is the key difference between attended and unattended runs?',
 'A desktop app for building Desktop Flows (RPA). Attended: a human is present at the machine. Unattended: runs without a logged-in user, requires an unattended add-on.',
 'teacher_john', 'teacher_john')

ON CONFLICT (id) DO NOTHING;

-- =============================================================================
-- PL-900 Practice Questions Space (folder_pl900_01)
-- 50 questions from Microsoft official practice assessment
-- =============================================================================

INSERT INTO spaces (id, folder_id, name, space_type, description, created_by, updated_by)
VALUES
    ('space_pl900_q01', 'folder_pl900_01',
     'PL-900 Practice Assessment',
     'Question',
     '50 official Microsoft PL-900 practice questions covering Power Apps, Power Automate, Power BI, Power Pages, Copilot Studio, and Dataverse.',
     'teacher_john', 'teacher_john')
ON CONFLICT (id) DO NOTHING;

INSERT INTO questions (id, space_id, question_type, body, created_by, updated_by)
VALUES
    ('q_pl900_01', 'space_pl900_q01', 'single', 'You build a solution by using Microsoft Power Platform and Microsoft Dataverse. You must use the default Currency table that comes with Microsoft Dataverse. You need to determine the table type for the Currency table. Which table type should you identify?', 'teacher_john', 'teacher_john'),
    ('q_pl900_02', 'space_pl900_q01', 'single', 'A company uses Microsoft Dataverse. You plan to create a one-to-many relationship between two tables named TableA and TableB in Microsoft Dataverse. You need to identify the column data type that is created for the relationship in TableB. What should you identify?', 'teacher_john', 'teacher_john'),
    ('q_pl900_03', 'space_pl900_q01', 'single', 'You plan to create a data model by using Microsoft Dataverse. You have a column that allows users to select one of two options: Approve or Reject. You need to identify the data type of the column. Which data type should you identify?', 'teacher_john', 'teacher_john'),
    ('q_pl900_04', 'space_pl900_q01', 'single', 'You have a Microsoft Dataverse environment. You create a business process flow for a table. The business process flow has three stages. You also create a business rule that runs when the status column value changes. You need to apply the business rule to each stage of the business process flow. What should you do?', 'teacher_john', 'teacher_john'),
    ('q_pl900_05', 'space_pl900_q01', 'single', 'You have a Power Platform environment. You need to assign users a role that allows them to manage the environment and its data. The solution must follow the principle of least privilege. Which role should you assign?', 'teacher_john', 'teacher_john'),
    ('q_pl900_06', 'space_pl900_q01', 'single', 'You have a Power Platform environment that contains a Microsoft Dataverse database. A user named User1 plans to create a canvas app named App1 that connects to Dataverse and to share App1 with other users. You need to assign User1 the minimum required security role. Which security role should you assign?', 'teacher_john', 'teacher_john'),
    ('q_pl900_07', 'space_pl900_q01', 'single', 'A company uses a set of model-driven apps within a single environment in Microsoft Power Platform. You need to share a new model-driven app with users. What should you use?', 'teacher_john', 'teacher_john'),
    ('q_pl900_08', 'space_pl900_q01', 'single', 'A coworker requires a personal Microsoft Power Platform environment to test preview features of Power Apps. The coworker wants to use this environment for as long as it is actively used. Which environment type should you recommend?', 'teacher_john', 'teacher_john'),
    ('q_pl900_09', 'space_pl900_q01', 'single', 'You have a Power Platform environment that uses Microsoft Dataverse. You need to ensure that users cannot access Dataverse data from outside of your company''''s tenant. What should you configure?', 'teacher_john', 'teacher_john'),
    ('q_pl900_10', 'space_pl900_q01', 'multiple', 'A company is considering using Power Pages for its website. You need to identify the capabilities of Power Pages. What are two capabilities of Power Pages? Each correct answer presents a complete solution.', 'teacher_john', 'teacher_john'),
    ('q_pl900_11', 'space_pl900_q01', 'single', 'A company is considering using Power Pages for its website. You need to determine whether the use cases for Power Pages meet the company''''s requirements. Which use case is supported by Power Pages?', 'teacher_john', 'teacher_john'),
    ('q_pl900_12', 'space_pl900_q01', 'single', 'You have a Power Platform environment. You plan to create a Microsoft Power Pages site that will serve as a customer self-service knowledge base. The site must use the URL https://contoso.com. What must you do first?', 'teacher_john', 'teacher_john'),
    ('q_pl900_13', 'space_pl900_q01', 'single', 'You have a Power Platform environment. You plan to create a website and provision a Microsoft Power Pages portal for the website. You need to provision the Power Pages site. Which URL should you use?', 'teacher_john', 'teacher_john'),
    ('q_pl900_14', 'space_pl900_q01', 'multiple', 'You create a Power Pages site. You need to share Dataverse data with external users. Which two components in Power Pages can you use to display data? Each correct answer presents a complete solution.', 'teacher_john', 'teacher_john'),
    ('q_pl900_15', 'space_pl900_q01', 'single', 'You have a business process that must be completed by external users. The process involves multiple steps that cannot be implemented by using model-driven apps. You need to implement the business process while minimizing development and licensing overhead. What should you use?', 'teacher_john', 'teacher_john'),
    ('q_pl900_16', 'space_pl900_q01', 'single', 'You have a Power Platform environment. You plan to create a Microsoft Dataverse table named Project. You need to ensure that users can perform the following tasks: create records in the table from Microsoft Teams, edit data from multiple devices, collaborate with other users directly in Teams. Which tool should you use to create the table?', 'teacher_john', 'teacher_john'),
    ('q_pl900_17', 'space_pl900_q01', 'single', 'A sales company plans to use Microsoft Power Platform and Dataverse to build solutions to help manage its day-to-day operations. The company requires a solution that will automatically remind sales representatives to update open opportunities each day. Which solution should you recommend?', 'teacher_john', 'teacher_john'),
    ('q_pl900_18', 'space_pl900_q01', 'single', 'You have a Microsoft Power Apps app that uses a Microsoft Dataverse database. When a user presses a button in the app, the solution must create a record in Dataverse and, at the same time, update a record in SharePoint Online. You need to implement the solution. What should you use?', 'teacher_john', 'teacher_john'),
    ('q_pl900_19', 'space_pl900_q01', 'single', 'You have a legacy desktop application that must be automated by using Microsoft Power Automate for desktop. The automation must read data from a file, enter the data into the legacy application, and then submit the data. In which order should you perform the actions?', 'teacher_john', 'teacher_john'),
    ('q_pl900_20', 'space_pl900_q01', 'single', 'You have a Microsoft Power Automate cloud flow. You need to create another flow that uses the same connectors as the first flow. The solution must minimize development effort. What should you create?', 'teacher_john', 'teacher_john'),
    ('q_pl900_21', 'space_pl900_q01', 'multiple', 'You plan to use the Microsoft Teams connector in a Power Automate cloud flow. Which two components are defined by the connector? Each correct answer presents a complete solution.', 'teacher_john', 'teacher_john'),
    ('q_pl900_22', 'space_pl900_q01', 'multiple', 'You need to build a workflow that sends an email each time a new item is added to a SharePoint Online list. Which two components should you use? Each correct answer presents a complete solution.', 'teacher_john', 'teacher_john'),
    ('q_pl900_23', 'space_pl900_q01', 'single', 'A company uses a Microsoft Copilot Studio copilot to manage routine customer requests. You use Power Automate to pass these requests to your back-end systems. Your back-end systems use a legacy application that does not have an API. Which type of flow should you use?', 'teacher_john', 'teacher_john'),
    ('q_pl900_24', 'space_pl900_q01', 'multiple', 'A company receives documents as PDF attachments by email. You need to process these documents automatically without user interaction by using Microsoft Power Platform. Which two components should you use? Each correct answer presents a complete solution.', 'teacher_john', 'teacher_john'),
    ('q_pl900_25', 'space_pl900_q01', 'single', 'You plan to create a flow using Power Automate. The flow will allow users to press a button in the Power Automate mobile app, which will send a reminder to a distribution list. Which type of flow should you create?', 'teacher_john', 'teacher_john'),
    ('q_pl900_26', 'space_pl900_q01', 'single', 'You have a Power Platform environment. You plan to create a flow in Microsoft Power Automate by using a template. You need to create a flow that posts a message in a Microsoft Teams channel when a video is uploaded to Microsoft Stream. Which type of flow should you create?', 'teacher_john', 'teacher_john'),
    ('q_pl900_27', 'space_pl900_q01', 'multiple', 'A company uses Microsoft Power Platform. You need to enable users to ask questions with natural language phrases. Which two Microsoft Power Platform components support this capability? Each correct answer presents a complete solution.', 'teacher_john', 'teacher_john'),
    ('q_pl900_28', 'space_pl900_q01', 'single', 'A company receives written letters. You need to allow users to record and track the letters. Which solution should you use?', 'teacher_john', 'teacher_john'),
    ('q_pl900_29', 'space_pl900_q01', 'single', 'You need to build a low-code application that includes online forms for collecting and displaying information from users. What should you use?', 'teacher_john', 'teacher_john'),
    ('q_pl900_30', 'space_pl900_q01', 'single', 'A company plans to use Microsoft Power Platform to transform its business. The company wants to digitize its invoice approval process to remove all manual steps. Which Microsoft Power Platform component should you recommend?', 'teacher_john', 'teacher_john'),
    ('q_pl900_31', 'space_pl900_q01', 'single', 'A company hosts conferences. You need to enable customers to view upcoming conferences hosted by your company. Which Power Apps component should you use?', 'teacher_john', 'teacher_john'),
    ('q_pl900_32', 'space_pl900_q01', 'single', 'A company uses Microsoft Power Platform. The company builds Power Apps canvas apps, Power BI dashboards, and Microsoft Copilot Studio. You need to identify a component that all of these solutions can share. Which component should you identify?', 'teacher_john', 'teacher_john'),
    ('q_pl900_33', 'space_pl900_q01', 'single', 'A company has a Power Pages site. You need to send a notification each week by using a third-party service. The notification must contain a summary of the data from the Power Pages site. Which Microsoft Power Platform component should you use?', 'teacher_john', 'teacher_john'),
    ('q_pl900_34', 'space_pl900_q01', 'single', 'You have a Power Platform environment. You need to create a canvas app that meets the following requirements: can be published in the Microsoft Teams channel, can connect to multiple data sources, supports high concurrency. Which tool should you use to create the app?', 'teacher_john', 'teacher_john'),
    ('q_pl900_35', 'space_pl900_q01', 'single', 'You have a Microsoft Excel file that contains employee expense information. The file is updated daily. You need to create a cloud flow that runs automatically when the file is updated. What should you add to the flow?', 'teacher_john', 'teacher_john'),
    ('q_pl900_36', 'space_pl900_q01', 'single', 'You are a business user who needs to guide other users through the stages and steps of a business process by using Microsoft Dataverse. You need to create a business process flow. Which Microsoft Power Platform component should you use?', 'teacher_john', 'teacher_john'),
    ('q_pl900_37', 'space_pl900_q01', 'single', 'You plan to create a Power Apps app. You need to enable users to read and write data from SharePoint and OneDrive for Business. What should you use?', 'teacher_john', 'teacher_john'),
    ('q_pl900_38', 'space_pl900_q01', 'single', 'You create an app. You need to ensure that the app displays data from an Azure SQL database. What should you use?', 'teacher_john', 'teacher_john'),
    ('q_pl900_39', 'space_pl900_q01', 'single', 'You have a Microsoft Power Apps app that uses a Microsoft Dataverse table named Assets. The environment also contains a table named Work Orders. You need to link records in the Assets table to records in the Work Orders table. What should you create?', 'teacher_john', 'teacher_john'),
    ('q_pl900_40', 'space_pl900_q01', 'single', 'You have a Microsoft Power Apps canvas app named App1 that records guest check-in details at a hotel. App1 uses a Microsoft Dataverse table. You need to add a form to record a guest''''s name, meal choice, and preferences. When a guest selects a meal option that is unavailable, a message must be displayed. What should you do?', 'teacher_john', 'teacher_john'),
    ('q_pl900_41', 'space_pl900_q01', 'single', 'You need to create a Microsoft Power Apps app that enables users to capture images and perform full CRUD operations of related data. What should you create?', 'teacher_john', 'teacher_john'),
    ('q_pl900_42', 'space_pl900_q01', 'multiple', 'You create a canvas app. You add a label control to your screen. You need to set the text color to red. What are three possible ways to achieve this goal? Each correct answer presents a complete solution.', 'teacher_john', 'teacher_john'),
    ('q_pl900_43', 'space_pl900_q01', 'multiple', 'A company uses Microsoft Power Platform. You need to recommend a use case for formulas in canvas apps. Which two actions should you recommend? Each correct answer presents a complete solution.', 'teacher_john', 'teacher_john'),
    ('q_pl900_44', 'space_pl900_q01', 'single', 'You create a canvas app. You need to format currency values in the app to always display two decimal places. Which code segment should you use?', 'teacher_john', 'teacher_john'),
    ('q_pl900_45', 'space_pl900_q01', 'multiple', 'A company uses Microsoft Power Platform. Which two controls in a canvas app can be connected to a data source? Each correct answer presents a complete solution.', 'teacher_john', 'teacher_john'),
    ('q_pl900_46', 'space_pl900_q01', 'multiple', 'You create a canvas app that is connected to a Microsoft Dataverse table. You need to share the app. Which two actions should you perform? Each correct answer presents a complete solution.', 'teacher_john', 'teacher_john'),
    ('q_pl900_47', 'space_pl900_q01', 'single', 'You configure a canvas app to track and order office stationery. The app allows users to order multiple stationery items. The items selected by the user must be reset each time a user reopens the app. Where should you store the selected items?', 'teacher_john', 'teacher_john'),
    ('q_pl900_48', 'space_pl900_q01', 'multiple', 'You build a canvas app. You need to allow users to select one or more values for a field. Which three controls should you use? Each correct answer presents a complete solution.', 'teacher_john', 'teacher_john'),
    ('q_pl900_49', 'space_pl900_q01', 'single', 'A company plans to use Microsoft Power Platform and Dataverse to transform its business. The company requires a central backend solution connected to Dataverse that includes business process flows for guiding employees. Which solution should you recommend?', 'teacher_john', 'teacher_john'),
    ('q_pl900_50', 'space_pl900_q01', 'single', 'A company has a model-driven app. You need to enable all users to access data in the app. What should you do?', 'teacher_john', 'teacher_john')
ON CONFLICT (id) DO NOTHING;

INSERT INTO answers (id, question_id, text, is_correct, position, created_by, updated_by)
VALUES
    ('a_pl900_01_0', 'q_pl900_01', 'Standard', TRUE, 0, 'teacher_john', 'teacher_john'),
    ('a_pl900_01_1', 'q_pl900_01', 'Activity', FALSE, 1, 'teacher_john', 'teacher_john'),
    ('a_pl900_01_2', 'q_pl900_01', 'Elastic', FALSE, 2, 'teacher_john', 'teacher_john'),
    ('a_pl900_01_3', 'q_pl900_01', 'Virtual', FALSE, 3, 'teacher_john', 'teacher_john'),
    ('a_pl900_02_0', 'q_pl900_02', 'Alternate key', FALSE, 0, 'teacher_john', 'teacher_john'),
    ('a_pl900_02_1', 'q_pl900_02', 'Customer', FALSE, 1, 'teacher_john', 'teacher_john'),
    ('a_pl900_02_2', 'q_pl900_02', 'Lookup', TRUE, 2, 'teacher_john', 'teacher_john'),
    ('a_pl900_02_3', 'q_pl900_02', 'Primary key', FALSE, 3, 'teacher_john', 'teacher_john'),
    ('a_pl900_03_0', 'q_pl900_03', 'Choice', FALSE, 0, 'teacher_john', 'teacher_john'),
    ('a_pl900_03_1', 'q_pl900_03', 'Choices', FALSE, 1, 'teacher_john', 'teacher_john'),
    ('a_pl900_03_2', 'q_pl900_03', 'Yes/No', TRUE, 2, 'teacher_john', 'teacher_john'),
    ('a_pl900_03_3', 'q_pl900_03', 'Text', FALSE, 3, 'teacher_john', 'teacher_john'),
    ('a_pl900_04_0', 'q_pl900_04', 'In the business process flow, activate the business rule.', FALSE, 0, 'teacher_john', 'teacher_john'),
    ('a_pl900_04_1', 'q_pl900_04', 'In the business process flow, add the business rule as a step.', FALSE, 1, 'teacher_john', 'teacher_john'),
    ('a_pl900_04_2', 'q_pl900_04', 'On the table, activate the business process flow.', FALSE, 2, 'teacher_john', 'teacher_john'),
    ('a_pl900_04_3', 'q_pl900_04', 'On the table, activate the business rule.', TRUE, 3, 'teacher_john', 'teacher_john'),
    ('a_pl900_05_0', 'q_pl900_05', 'Delegate', FALSE, 0, 'teacher_john', 'teacher_john'),
    ('a_pl900_05_1', 'q_pl900_05', 'Environment Admin', TRUE, 1, 'teacher_john', 'teacher_john'),
    ('a_pl900_05_2', 'q_pl900_05', 'Environment Maker', FALSE, 2, 'teacher_john', 'teacher_john'),
    ('a_pl900_05_3', 'q_pl900_05', 'System Administrator', FALSE, 3, 'teacher_john', 'teacher_john'),
    ('a_pl900_06_0', 'q_pl900_06', 'Delegated Admin', FALSE, 0, 'teacher_john', 'teacher_john'),
    ('a_pl900_06_1', 'q_pl900_06', 'Environment Maker', TRUE, 1, 'teacher_john', 'teacher_john'),
    ('a_pl900_06_2', 'q_pl900_06', 'System Administrator', FALSE, 2, 'teacher_john', 'teacher_john'),
    ('a_pl900_06_3', 'q_pl900_06', 'System Customizer', FALSE, 3, 'teacher_john', 'teacher_john'),
    ('a_pl900_07_0', 'q_pl900_07', 'Data loss prevention (DLP) policy', FALSE, 0, 'teacher_john', 'teacher_john'),
    ('a_pl900_07_1', 'q_pl900_07', 'Microsoft 365 security group', FALSE, 1, 'teacher_john', 'teacher_john'),
    ('a_pl900_07_2', 'q_pl900_07', 'App security role', TRUE, 2, 'teacher_john', 'teacher_john'),
    ('a_pl900_07_3', 'q_pl900_07', 'Business process flow', FALSE, 3, 'teacher_john', 'teacher_john'),
    ('a_pl900_08_0', 'q_pl900_08', 'Default', FALSE, 0, 'teacher_john', 'teacher_john'),
    ('a_pl900_08_1', 'q_pl900_08', 'Production', FALSE, 1, 'teacher_john', 'teacher_john'),
    ('a_pl900_08_2', 'q_pl900_08', 'Developer', TRUE, 2, 'teacher_john', 'teacher_john'),
    ('a_pl900_08_3', 'q_pl900_08', 'Trial', FALSE, 3, 'teacher_john', 'teacher_john'),
    ('a_pl900_09_0', 'q_pl900_09', 'a data loss prevention (DLP) policy in the Power Platform admin center', FALSE, 0, 'teacher_john', 'teacher_john'),
    ('a_pl900_09_1', 'q_pl900_09', 'a Microsoft Entra Conditional Access policy', TRUE, 1, 'teacher_john', 'teacher_john'),
    ('a_pl900_09_2', 'q_pl900_09', 'a Microsoft Entra password protection policy', FALSE, 2, 'teacher_john', 'teacher_john'),
    ('a_pl900_09_3', 'q_pl900_09', 'a Microsoft Entra security group', FALSE, 3, 'teacher_john', 'teacher_john'),
    ('a_pl900_10_0', 'q_pl900_10', 'automating business processes', FALSE, 0, 'teacher_john', 'teacher_john'),
    ('a_pl900_10_1', 'q_pl900_10', 'building sites by using low-code tools', TRUE, 1, 'teacher_john', 'teacher_john'),
    ('a_pl900_10_2', 'q_pl900_10', 'creating documents from templates', FALSE, 2, 'teacher_john', 'teacher_john'),
    ('a_pl900_10_3', 'q_pl900_10', 'exposing data in Dataverse to customers', TRUE, 3, 'teacher_john', 'teacher_john'),
    ('a_pl900_10_4', 'q_pl900_10', 'extracting data from documents', FALSE, 4, 'teacher_john', 'teacher_john'),
    ('a_pl900_11_0', 'q_pl900_11', 'Capturing data from customers.', TRUE, 0, 'teacher_john', 'teacher_john'),
    ('a_pl900_11_1', 'q_pl900_11', 'Carrying out integration between systems.', FALSE, 1, 'teacher_john', 'teacher_john'),
    ('a_pl900_11_2', 'q_pl900_11', 'Automating interactions with legacy Windows applications that don''''t have APIs.', FALSE, 2, 'teacher_john', 'teacher_john'),
    ('a_pl900_11_3', 'q_pl900_11', 'Creating visualizations of data.', FALSE, 3, 'teacher_john', 'teacher_john'),
    ('a_pl900_12_0', 'q_pl900_12', 'Create a DNS record for https://contoso.com.', FALSE, 0, 'teacher_john', 'teacher_john'),
    ('a_pl900_12_1', 'q_pl900_12', 'Create a Microsoft Power Automate flow.', FALSE, 1, 'teacher_john', 'teacher_john'),
    ('a_pl900_12_2', 'q_pl900_12', 'Create a new environment that contains a Microsoft Dataverse database.', TRUE, 2, 'teacher_john', 'teacher_john'),
    ('a_pl900_12_3', 'q_pl900_12', 'Create a new environment that does NOT contain a Microsoft Dataverse database.', FALSE, 3, 'teacher_john', 'teacher_john'),
    ('a_pl900_13_0', 'q_pl900_13', 'https://app.powerbi.com/', FALSE, 0, 'teacher_john', 'teacher_john'),
    ('a_pl900_13_1', 'q_pl900_13', 'https://make.powerapps.com/', FALSE, 1, 'teacher_john', 'teacher_john'),
    ('a_pl900_13_2', 'q_pl900_13', 'https://make.powerautomate.com/', FALSE, 2, 'teacher_john', 'teacher_john'),
    ('a_pl900_13_3', 'q_pl900_13', 'https://make.powerpages.microsoft.com/', TRUE, 3, 'teacher_john', 'teacher_john'),
    ('a_pl900_14_0', 'q_pl900_14', 'form', TRUE, 0, 'teacher_john', 'teacher_john'),
    ('a_pl900_14_1', 'q_pl900_14', 'iframe', FALSE, 1, 'teacher_john', 'teacher_john'),
    ('a_pl900_14_2', 'q_pl900_14', 'list', TRUE, 2, 'teacher_john', 'teacher_john'),
    ('a_pl900_14_3', 'q_pl900_14', 'text', FALSE, 3, 'teacher_john', 'teacher_john'),
    ('a_pl900_15_0', 'q_pl900_15', 'a business process flow', FALSE, 0, 'teacher_john', 'teacher_john'),
    ('a_pl900_15_1', 'q_pl900_15', 'an instant flow', FALSE, 1, 'teacher_john', 'teacher_john'),
    ('a_pl900_15_2', 'q_pl900_15', 'canvas apps', FALSE, 2, 'teacher_john', 'teacher_john'),
    ('a_pl900_15_3', 'q_pl900_15', 'Microsoft Power Pages', TRUE, 3, 'teacher_john', 'teacher_john'),
    ('a_pl900_16_0', 'q_pl900_16', 'Microsoft Copilot Studio', FALSE, 0, 'teacher_john', 'teacher_john'),
    ('a_pl900_16_1', 'q_pl900_16', 'Microsoft Power Apps', TRUE, 1, 'teacher_john', 'teacher_john'),
    ('a_pl900_16_2', 'q_pl900_16', 'Microsoft Power BI', FALSE, 2, 'teacher_john', 'teacher_john'),
    ('a_pl900_16_3', 'q_pl900_16', 'Microsoft Power Pages', FALSE, 3, 'teacher_john', 'teacher_john'),
    ('a_pl900_17_0', 'q_pl900_17', 'automatic flow that is triggered when an appointment is updated', FALSE, 0, 'teacher_john', 'teacher_john'),
    ('a_pl900_17_1', 'q_pl900_17', 'scheduled flow that runs daily at a specific time', TRUE, 1, 'teacher_john', 'teacher_john'),
    ('a_pl900_17_2', 'q_pl900_17', 'instant flow triggered when someone selects a button', FALSE, 2, 'teacher_john', 'teacher_john'),
    ('a_pl900_17_3', 'q_pl900_17', 'automatic flow that is triggered when a new appointment is created', FALSE, 3, 'teacher_john', 'teacher_john'),
    ('a_pl900_18_0', 'q_pl900_18', 'a business process flow', FALSE, 0, 'teacher_john', 'teacher_john'),
    ('a_pl900_18_1', 'q_pl900_18', 'a business rule', FALSE, 1, 'teacher_john', 'teacher_john'),
    ('a_pl900_18_2', 'q_pl900_18', 'a cloud flow', TRUE, 2, 'teacher_john', 'teacher_john'),
    ('a_pl900_18_3', 'q_pl900_18', 'a desktop flow', FALSE, 3, 'teacher_john', 'teacher_john'),
    ('a_pl900_19_0', 'q_pl900_19', 'Extract data from the file, enter the data, and then launch and activate the legacy application.', FALSE, 0, 'teacher_john', 'teacher_john'),
    ('a_pl900_19_1', 'q_pl900_19', 'Extract data from the file, launch and activate the legacy application, and then enter the data.', TRUE, 1, 'teacher_john', 'teacher_john'),
    ('a_pl900_19_2', 'q_pl900_19', 'Launch and activate the legacy application, enter the data, and then extract data from the file.', FALSE, 2, 'teacher_john', 'teacher_john'),
    ('a_pl900_19_3', 'q_pl900_19', 'Launch and activate the legacy application, extract data from the file, and then enter the data.', FALSE, 3, 'teacher_john', 'teacher_john'),
    ('a_pl900_20_0', 'q_pl900_20', 'a cloud flow from a connector', FALSE, 0, 'teacher_john', 'teacher_john'),
    ('a_pl900_20_1', 'q_pl900_20', 'a cloud flow from a solution', FALSE, 1, 'teacher_john', 'teacher_john'),
    ('a_pl900_20_2', 'q_pl900_20', 'a cloud flow from a template', TRUE, 2, 'teacher_john', 'teacher_john'),
    ('a_pl900_20_3', 'q_pl900_20', 'a cloud flow from blank', FALSE, 3, 'teacher_john', 'teacher_john'),
    ('a_pl900_21_0', 'q_pl900_21', 'Actions', TRUE, 0, 'teacher_john', 'teacher_john'),
    ('a_pl900_21_1', 'q_pl900_21', 'Credentials', FALSE, 1, 'teacher_john', 'teacher_john'),
    ('a_pl900_21_2', 'q_pl900_21', 'Postman collection', FALSE, 2, 'teacher_john', 'teacher_john'),
    ('a_pl900_21_3', 'q_pl900_21', 'Triggers', TRUE, 3, 'teacher_john', 'teacher_john'),
    ('a_pl900_22_0', 'q_pl900_22', 'Power Apps', FALSE, 0, 'teacher_john', 'teacher_john'),
    ('a_pl900_22_1', 'q_pl900_22', 'Power Automate', TRUE, 1, 'teacher_john', 'teacher_john'),
    ('a_pl900_22_2', 'q_pl900_22', 'Power BI', FALSE, 2, 'teacher_john', 'teacher_john'),
    ('a_pl900_22_3', 'q_pl900_22', 'Microsoft Copilot Studio', FALSE, 3, 'teacher_john', 'teacher_john'),
    ('a_pl900_22_4', 'q_pl900_22', 'Connectors', TRUE, 4, 'teacher_john', 'teacher_john'),
    ('a_pl900_23_0', 'q_pl900_23', 'Connector', FALSE, 0, 'teacher_john', 'teacher_john'),
    ('a_pl900_23_1', 'q_pl900_23', 'cloud flow', FALSE, 1, 'teacher_john', 'teacher_john'),
    ('a_pl900_23_2', 'q_pl900_23', 'desktop flow', TRUE, 2, 'teacher_john', 'teacher_john'),
    ('a_pl900_23_3', 'q_pl900_23', 'business process flow', FALSE, 3, 'teacher_john', 'teacher_john'),
    ('a_pl900_24_0', 'q_pl900_24', 'AI Builder', TRUE, 0, 'teacher_john', 'teacher_john'),
    ('a_pl900_24_1', 'q_pl900_24', 'Canvas app', FALSE, 1, 'teacher_john', 'teacher_john'),
    ('a_pl900_24_2', 'q_pl900_24', 'Power Automate cloud flow', TRUE, 2, 'teacher_john', 'teacher_john'),
    ('a_pl900_24_3', 'q_pl900_24', 'Power BI', FALSE, 3, 'teacher_john', 'teacher_john'),
    ('a_pl900_24_4', 'q_pl900_24', 'Copilot Studio', FALSE, 4, 'teacher_john', 'teacher_john'),
    ('a_pl900_25_0', 'q_pl900_25', 'Scheduled', FALSE, 0, 'teacher_john', 'teacher_john'),
    ('a_pl900_25_1', 'q_pl900_25', 'Automated', FALSE, 1, 'teacher_john', 'teacher_john'),
    ('a_pl900_25_2', 'q_pl900_25', 'Business process', FALSE, 2, 'teacher_john', 'teacher_john'),
    ('a_pl900_25_3', 'q_pl900_25', 'Instant', TRUE, 3, 'teacher_john', 'teacher_john'),
    ('a_pl900_26_0', 'q_pl900_26', 'a business process flow', FALSE, 0, 'teacher_john', 'teacher_john'),
    ('a_pl900_26_1', 'q_pl900_26', 'a scheduled cloud flow', FALSE, 1, 'teacher_john', 'teacher_john'),
    ('a_pl900_26_2', 'q_pl900_26', 'an automated cloud flow', TRUE, 2, 'teacher_john', 'teacher_john'),
    ('a_pl900_26_3', 'q_pl900_26', 'an instant cloud flow', FALSE, 3, 'teacher_john', 'teacher_john'),
    ('a_pl900_27_0', 'q_pl900_27', 'Power Automate', FALSE, 0, 'teacher_john', 'teacher_john'),
    ('a_pl900_27_1', 'q_pl900_27', 'Power Apps', FALSE, 1, 'teacher_john', 'teacher_john'),
    ('a_pl900_27_2', 'q_pl900_27', 'Power BI', TRUE, 2, 'teacher_john', 'teacher_john'),
    ('a_pl900_27_3', 'q_pl900_27', 'Microsoft Copilot Studio', TRUE, 3, 'teacher_john', 'teacher_john'),
    ('a_pl900_27_4', 'q_pl900_27', 'Microsoft Dataverse', FALSE, 4, 'teacher_john', 'teacher_john'),
    ('a_pl900_28_0', 'q_pl900_28', 'Power Automate', FALSE, 0, 'teacher_john', 'teacher_john'),
    ('a_pl900_28_1', 'q_pl900_28', 'Microsoft Copilot Studio', FALSE, 1, 'teacher_john', 'teacher_john'),
    ('a_pl900_28_2', 'q_pl900_28', 'Power Apps', TRUE, 2, 'teacher_john', 'teacher_john'),
    ('a_pl900_28_3', 'q_pl900_28', 'Power BI', FALSE, 3, 'teacher_john', 'teacher_john'),
    ('a_pl900_29_0', 'q_pl900_29', 'Power Automate', FALSE, 0, 'teacher_john', 'teacher_john'),
    ('a_pl900_29_1', 'q_pl900_29', 'Power BI', FALSE, 1, 'teacher_john', 'teacher_john'),
    ('a_pl900_29_2', 'q_pl900_29', 'Microsoft Copilot Studio', FALSE, 2, 'teacher_john', 'teacher_john'),
    ('a_pl900_29_3', 'q_pl900_29', 'Power Apps', TRUE, 3, 'teacher_john', 'teacher_john'),
    ('a_pl900_30_0', 'q_pl900_30', 'Power Apps', FALSE, 0, 'teacher_john', 'teacher_john'),
    ('a_pl900_30_1', 'q_pl900_30', 'Power Automate', TRUE, 1, 'teacher_john', 'teacher_john'),
    ('a_pl900_30_2', 'q_pl900_30', 'Power BI', FALSE, 2, 'teacher_john', 'teacher_john'),
    ('a_pl900_30_3', 'q_pl900_30', 'Power Pages', FALSE, 3, 'teacher_john', 'teacher_john'),
    ('a_pl900_31_0', 'q_pl900_31', 'Canvas app', FALSE, 0, 'teacher_john', 'teacher_john'),
    ('a_pl900_31_1', 'q_pl900_31', 'Model-driven app', FALSE, 1, 'teacher_john', 'teacher_john'),
    ('a_pl900_31_2', 'q_pl900_31', 'Power Pages', TRUE, 2, 'teacher_john', 'teacher_john'),
    ('a_pl900_31_3', 'q_pl900_31', 'Business process flow', FALSE, 3, 'teacher_john', 'teacher_john'),
    ('a_pl900_32_0', 'q_pl900_32', 'AI Builder', FALSE, 0, 'teacher_john', 'teacher_john'),
    ('a_pl900_32_1', 'q_pl900_32', 'Model-driven apps', FALSE, 1, 'teacher_john', 'teacher_john'),
    ('a_pl900_32_2', 'q_pl900_32', 'Power Automate', FALSE, 2, 'teacher_john', 'teacher_john'),
    ('a_pl900_32_3', 'q_pl900_32', 'Microsoft Dataverse', TRUE, 3, 'teacher_john', 'teacher_john'),
    ('a_pl900_33_0', 'q_pl900_33', 'Power Automate', TRUE, 0, 'teacher_john', 'teacher_john'),
    ('a_pl900_33_1', 'q_pl900_33', 'Power BI', FALSE, 1, 'teacher_john', 'teacher_john'),
    ('a_pl900_33_2', 'q_pl900_33', 'Microsoft Copilot Studio', FALSE, 2, 'teacher_john', 'teacher_john'),
    ('a_pl900_33_3', 'q_pl900_33', 'Microsoft Dataverse', FALSE, 3, 'teacher_john', 'teacher_john'),
    ('a_pl900_34_0', 'q_pl900_34', 'Microsoft Dataverse', FALSE, 0, 'teacher_john', 'teacher_john'),
    ('a_pl900_34_1', 'q_pl900_34', 'Microsoft Power Apps Studio', TRUE, 1, 'teacher_john', 'teacher_john'),
    ('a_pl900_34_2', 'q_pl900_34', 'the Microsoft Power Apps mobile app', FALSE, 2, 'teacher_john', 'teacher_john'),
    ('a_pl900_34_3', 'q_pl900_34', 'the Power Apps maker portal', FALSE, 3, 'teacher_john', 'teacher_john'),
    ('a_pl900_35_0', 'q_pl900_35', 'a Microsoft OneDrive action', FALSE, 0, 'teacher_john', 'teacher_john'),
    ('a_pl900_35_1', 'q_pl900_35', 'a Microsoft OneDrive trigger', TRUE, 1, 'teacher_john', 'teacher_john'),
    ('a_pl900_35_2', 'q_pl900_35', 'a Microsoft Power Apps action', FALSE, 2, 'teacher_john', 'teacher_john'),
    ('a_pl900_35_3', 'q_pl900_35', 'a Microsoft Power Apps trigger', FALSE, 3, 'teacher_john', 'teacher_john'),
    ('a_pl900_36_0', 'q_pl900_36', 'Microsoft Copilot Studio', FALSE, 0, 'teacher_john', 'teacher_john'),
    ('a_pl900_36_1', 'q_pl900_36', 'Microsoft Power Apps', FALSE, 1, 'teacher_john', 'teacher_john'),
    ('a_pl900_36_2', 'q_pl900_36', 'Microsoft Power Automate', TRUE, 2, 'teacher_john', 'teacher_john'),
    ('a_pl900_36_3', 'q_pl900_36', 'Microsoft Power BI', FALSE, 3, 'teacher_john', 'teacher_john'),
    ('a_pl900_37_0', 'q_pl900_37', 'A Canvas app', TRUE, 0, 'teacher_john', 'teacher_john'),
    ('a_pl900_37_1', 'q_pl900_37', 'A Model-driven app', FALSE, 1, 'teacher_john', 'teacher_john'),
    ('a_pl900_37_2', 'q_pl900_37', 'Power Pages', FALSE, 2, 'teacher_john', 'teacher_john'),
    ('a_pl900_37_3', 'q_pl900_37', 'A Business process flow', FALSE, 3, 'teacher_john', 'teacher_john'),
    ('a_pl900_38_0', 'q_pl900_38', 'Model-driven app', FALSE, 0, 'teacher_john', 'teacher_john'),
    ('a_pl900_38_1', 'q_pl900_38', 'Power Pages', FALSE, 1, 'teacher_john', 'teacher_john'),
    ('a_pl900_38_2', 'q_pl900_38', 'Canvas apps', TRUE, 2, 'teacher_john', 'teacher_john'),
    ('a_pl900_38_3', 'q_pl900_38', 'Microsoft Dataverse', FALSE, 3, 'teacher_john', 'teacher_john'),
    ('a_pl900_39_0', 'q_pl900_39', 'a business process flow', FALSE, 0, 'teacher_john', 'teacher_john'),
    ('a_pl900_39_1', 'q_pl900_39', 'a business rule', FALSE, 1, 'teacher_john', 'teacher_john'),
    ('a_pl900_39_2', 'q_pl900_39', 'a model-driven app', FALSE, 2, 'teacher_john', 'teacher_john'),
    ('a_pl900_39_3', 'q_pl900_39', 'a relationship', TRUE, 3, 'teacher_john', 'teacher_john'),
    ('a_pl900_40_0', 'q_pl900_40', 'Add a form and fields and use the OnSubmit property to show the message.', FALSE, 0, 'teacher_john', 'teacher_john'),
    ('a_pl900_40_1', 'q_pl900_40', 'Add an Edit form bound to Dataverse and include the required fields. Use a formula on the meal choice control to display the message.', TRUE, 1, 'teacher_john', 'teacher_john'),
    ('a_pl900_40_2', 'q_pl900_40', 'Add the column that contains each guest''''s meal choice, rename it Guest Meal Choice, and mark the Name field as required.', FALSE, 2, 'teacher_john', 'teacher_john'),
    ('a_pl900_40_3', 'q_pl900_40', 'Create a new app that uses the existing Dataverse table.', FALSE, 3, 'teacher_john', 'teacher_john'),
    ('a_pl900_41_0', 'q_pl900_41', 'A canvas app', TRUE, 0, 'teacher_john', 'teacher_john'),
    ('a_pl900_41_1', 'q_pl900_41', 'A Microsoft Power Automate desktop flow', FALSE, 1, 'teacher_john', 'teacher_john'),
    ('a_pl900_41_2', 'q_pl900_41', 'A Microsoft Power BI app', FALSE, 2, 'teacher_john', 'teacher_john'),
    ('a_pl900_41_3', 'q_pl900_41', 'A model-driven app', FALSE, 3, 'teacher_john', 'teacher_john'),
    ('a_pl900_42_0', 'q_pl900_42', 'Select the label control. Select the color picker control in the toolbar and choose red from the color menu.', TRUE, 0, 'teacher_john', 'teacher_john'),
    ('a_pl900_42_1', 'q_pl900_42', 'Select the label control. Choose the Fill property in the formula bar. Set the formula value to Color.Red.', FALSE, 1, 'teacher_john', 'teacher_john'),
    ('a_pl900_42_2', 'q_pl900_42', 'Select the label control. Choose the Color property in the formula bar. Set the formula value to Color.Red.', TRUE, 2, 'teacher_john', 'teacher_john'),
    ('a_pl900_42_3', 'q_pl900_42', 'Select the label control. Open the Properties pane and choose the Advanced tab. Find the Fill property and add Color.Red to the textbox.', FALSE, 3, 'teacher_john', 'teacher_john'),
    ('a_pl900_42_4', 'q_pl900_42', 'Select the label control. Open the Properties pane and choose the Advanced tab. Find the Color property and add Color.Red to the textbox.', TRUE, 4, 'teacher_john', 'teacher_john'),
    ('a_pl900_43_0', 'q_pl900_43', 'Control which users can run a canvas app.', FALSE, 0, 'teacher_john', 'teacher_john'),
    ('a_pl900_43_1', 'q_pl900_43', 'Filter a list of rows.', TRUE, 1, 'teacher_john', 'teacher_john'),
    ('a_pl900_43_2', 'q_pl900_43', 'Save data when a user selects a button.', TRUE, 2, 'teacher_john', 'teacher_john'),
    ('a_pl900_43_3', 'q_pl900_43', 'Return XML data from a web page.', FALSE, 3, 'teacher_john', 'teacher_john'),
    ('a_pl900_44_0', 'q_pl900_44', 'Text("Currency value", "$#, ###0.00")', TRUE, 0, 'teacher_john', 'teacher_john'),
    ('a_pl900_44_1', 'q_pl900_44', 'Match("Currency value", "#,###0.00")', FALSE, 1, 'teacher_john', 'teacher_john'),
    ('a_pl900_44_2', 'q_pl900_44', 'PlainText("Currency value", "#,###0.00")', FALSE, 2, 'teacher_john', 'teacher_john'),
    ('a_pl900_44_3', 'q_pl900_44', 'Value("Currency value", "#,###0.00")', FALSE, 3, 'teacher_john', 'teacher_john'),
    ('a_pl900_45_0', 'q_pl900_45', 'Button', FALSE, 0, 'teacher_john', 'teacher_john'),
    ('a_pl900_45_1', 'q_pl900_45', 'Form', TRUE, 1, 'teacher_john', 'teacher_john'),
    ('a_pl900_45_2', 'q_pl900_45', 'Gallery', TRUE, 2, 'teacher_john', 'teacher_john'),
    ('a_pl900_45_3', 'q_pl900_45', 'Screen', FALSE, 3, 'teacher_john', 'teacher_john'),
    ('a_pl900_46_0', 'q_pl900_46', 'Notify the users by email.', FALSE, 0, 'teacher_john', 'teacher_john'),
    ('a_pl900_46_1', 'q_pl900_46', 'Allow the users to edit the app.', FALSE, 1, 'teacher_john', 'teacher_john'),
    ('a_pl900_46_2', 'q_pl900_46', 'Publish the app.', TRUE, 2, 'teacher_john', 'teacher_john'),
    ('a_pl900_46_3', 'q_pl900_46', 'Assign a security role.', TRUE, 3, 'teacher_john', 'teacher_john'),
    ('a_pl900_47_0', 'q_pl900_47', 'A Collection', TRUE, 0, 'teacher_john', 'teacher_john'),
    ('a_pl900_47_1', 'q_pl900_47', 'Dataverse', FALSE, 1, 'teacher_john', 'teacher_john'),
    ('a_pl900_47_2', 'q_pl900_47', 'SharePoint', FALSE, 2, 'teacher_john', 'teacher_john'),
    ('a_pl900_47_3', 'q_pl900_47', 'A Variable', FALSE, 3, 'teacher_john', 'teacher_john'),
    ('a_pl900_48_0', 'q_pl900_48', 'Radio', FALSE, 0, 'teacher_john', 'teacher_john'),
    ('a_pl900_48_1', 'q_pl900_48', 'Combo box', TRUE, 1, 'teacher_john', 'teacher_john'),
    ('a_pl900_48_2', 'q_pl900_48', 'Drop-down', TRUE, 2, 'teacher_john', 'teacher_john'),
    ('a_pl900_48_3', 'q_pl900_48', 'List box', TRUE, 3, 'teacher_john', 'teacher_john'),
    ('a_pl900_48_4', 'q_pl900_48', 'Rating', FALSE, 4, 'teacher_john', 'teacher_john'),
    ('a_pl900_49_0', 'q_pl900_49', 'canvas application', FALSE, 0, 'teacher_john', 'teacher_john'),
    ('a_pl900_49_1', 'q_pl900_49', 'desktop flow', FALSE, 1, 'teacher_john', 'teacher_john'),
    ('a_pl900_49_2', 'q_pl900_49', 'Power Pages site', FALSE, 2, 'teacher_john', 'teacher_john'),
    ('a_pl900_49_3', 'q_pl900_49', 'Model Driven Apps', TRUE, 3, 'teacher_john', 'teacher_john'),
    ('a_pl900_50_0', 'q_pl900_50', 'Create a new table.', FALSE, 0, 'teacher_john', 'teacher_john'),
    ('a_pl900_50_1', 'q_pl900_50', 'Create a new model-driven app.', FALSE, 1, 'teacher_john', 'teacher_john'),
    ('a_pl900_50_2', 'q_pl900_50', 'Create a new personal view.', FALSE, 2, 'teacher_john', 'teacher_john'),
    ('a_pl900_50_3', 'q_pl900_50', 'Create a new public view.', TRUE, 3, 'teacher_john', 'teacher_john')
ON CONFLICT (id) DO NOTHING;

-- =============================================================================
-- PL-900 Additional 100 Practice Questions (Q51–Q150)
-- Topics: Power BI, Power Automate, Dataverse, Copilot Studio, AI Builder, General
-- =============================================================================

INSERT INTO questions (id, space_id, question_type, body, created_by, updated_by)
VALUES
    -- Power BI (Q51–Q65)
    ('q_pl900_51', 'space_pl900_q01', 'single', 'A team needs to collaborate on Power BI reports and dashboards. Which Power BI feature provides a shared space for the team to create and manage content?', 'teacher_john', 'teacher_john'),
    ('q_pl900_52', 'space_pl900_q01', 'single', 'You need to build Power BI reports and connect them to multiple data sources before publishing. Which tool should you use?', 'teacher_john', 'teacher_john'),
    ('q_pl900_53', 'space_pl900_q01', 'single', 'You have several Power BI reports in a workspace. You need to create a single-page overview that combines key visuals from multiple reports. What should you create?', 'teacher_john', 'teacher_john'),
    ('q_pl900_54', 'space_pl900_q01', 'single', 'A company needs to share Power BI reports with users outside their organization. Which feature should you use?', 'teacher_john', 'teacher_john'),
    ('q_pl900_55', 'space_pl900_q01', 'single', 'You need to create a Power BI visualization that shows sales trends over a 12-month period. Which visualization type should you use?', 'teacher_john', 'teacher_john'),
    ('q_pl900_56', 'space_pl900_q01', 'single', 'You have a Power BI report connected to an on-premises SQL Server database. The report data must be updated daily. What should you configure?', 'teacher_john', 'teacher_john'),
    ('q_pl900_57', 'space_pl900_q01', 'single', 'A business user wants to explore Power BI data by typing questions in plain English and receiving instant visual answers. Which Power BI feature should they use?', 'teacher_john', 'teacher_john'),
    ('q_pl900_58', 'space_pl900_q01', 'single', 'You need to add an interactive filter to a Power BI report page so that users can filter all visuals by selecting a date range. Which visualization type should you add?', 'teacher_john', 'teacher_john'),
    ('q_pl900_59', 'space_pl900_q01', 'multiple', 'You need to identify two Power BI visualization types best suited for comparing values across multiple categories. Which two should you select? Each correct answer presents a complete solution.', 'teacher_john', 'teacher_john'),
    ('q_pl900_60', 'space_pl900_q01', 'single', 'A user needs to share a Power BI report with colleagues in the same organization. Which license is required for both the creator and the viewer to share and access the report?', 'teacher_john', 'teacher_john'),
    ('q_pl900_61', 'space_pl900_q01', 'single', 'A company wants to embed Power BI reports into a public-facing website for anonymous users. Which Power BI offering should you use?', 'teacher_john', 'teacher_john'),
    ('q_pl900_62', 'space_pl900_q01', 'single', 'Your Power BI reports use an on-premises SQL Server database. You need the Power BI service to access this database for scheduled refreshes. What should you install?', 'teacher_john', 'teacher_john'),
    ('q_pl900_63', 'space_pl900_q01', 'single', 'You want to receive an email notification when a KPI tile on a Power BI dashboard exceeds a specific threshold. Which Power BI feature should you configure?', 'teacher_john', 'teacher_john'),
    ('q_pl900_64', 'space_pl900_q01', 'single', 'A company wants to distribute a curated set of Power BI dashboards and reports to a large group of users within the organization. What should you create?', 'teacher_john', 'teacher_john'),
    ('q_pl900_65', 'space_pl900_q01', 'single', 'A company needs to produce highly formatted, printable financial statements using Power BI. Which tool should you use?', 'teacher_john', 'teacher_john'),
    -- Power Automate (Q66–Q75)
    ('q_pl900_66', 'space_pl900_q01', 'single', 'You need to create a Power Automate flow that starts automatically when a new email arrives in an Outlook inbox. Which type of trigger should you use?', 'teacher_john', 'teacher_john'),
    ('q_pl900_67', 'space_pl900_q01', 'single', 'A company needs an expense approval process where a manager must approve or reject before the flow continues. Which Power Automate action should you add?', 'teacher_john', 'teacher_john'),
    ('q_pl900_68', 'space_pl900_q01', 'single', 'You have a cloud flow that retrieves a record value. You need to perform different actions depending on whether the value is greater than 100. What should you add to the flow?', 'teacher_john', 'teacher_john'),
    ('q_pl900_69', 'space_pl900_q01', 'single', 'A company uses Power Automate for desktop to automate tasks on a user workstation. The automation requires the user to be signed in and present during execution. Which type of desktop flow should you use?', 'teacher_john', 'teacher_john'),
    ('q_pl900_70', 'space_pl900_q01', 'single', 'You need to connect a Power Automate flow to a third-party REST API that has no built-in Power Platform connector. What should you create?', 'teacher_john', 'teacher_john'),
    ('q_pl900_71', 'space_pl900_q01', 'single', 'A company wants to use the Salesforce connector in Power Automate. Which connector category does the Salesforce connector belong to?', 'teacher_john', 'teacher_john'),
    ('q_pl900_72', 'space_pl900_q01', 'single', 'You have a Power Automate cloud flow that returns a list of Dataverse records. You need to send an email for each record in the list. What should you add to the flow?', 'teacher_john', 'teacher_john'),
    ('q_pl900_73', 'space_pl900_q01', 'multiple', 'You need to identify which two components are defined by a Power Platform connector. Which two components should you identify? Each correct answer presents a complete solution.', 'teacher_john', 'teacher_john'),
    ('q_pl900_74', 'space_pl900_q01', 'single', 'A company wants to run Power Automate desktop flows overnight on a virtual machine without any user being signed in. Which type of desktop flow should you use?', 'teacher_john', 'teacher_john'),
    ('q_pl900_75', 'space_pl900_q01', 'single', 'An action in a Power Automate cloud flow sometimes fails. You need to add a notification step that runs only when that action fails. What should you configure on the notification action?', 'teacher_john', 'teacher_john'),
    -- Dataverse (Q76–Q85)
    ('q_pl900_76', 'space_pl900_q01', 'single', 'What is the primary purpose of a security role in Microsoft Dataverse?', 'teacher_john', 'teacher_john'),
    ('q_pl900_77', 'space_pl900_q01', 'single', 'You have a Dataverse table named Orders with related order line items. You need a column on the Orders table that automatically sums the quantity from all related line item records. Which type of column should you create?', 'teacher_john', 'teacher_john'),
    ('q_pl900_78', 'space_pl900_q01', 'single', 'A company must track all changes made to Dataverse records for compliance. What should you enable on the table?', 'teacher_john', 'teacher_john'),
    ('q_pl900_79', 'space_pl900_q01', 'single', 'What best describes a Microsoft Dataverse environment?', 'teacher_john', 'teacher_john'),
    ('q_pl900_80', 'space_pl900_q01', 'single', 'You need to enforce a rule in a Dataverse table that makes a column required based on the value of another column, without writing code. Which feature should you use?', 'teacher_john', 'teacher_john'),
    ('q_pl900_81', 'space_pl900_q01', 'single', 'You have built Power Apps, flows, and Dataverse customizations in a development environment. You need to package and deploy all components to a production environment. What should you use?', 'teacher_john', 'teacher_john'),
    ('q_pl900_82', 'space_pl900_q01', 'multiple', 'You need to store numeric values in a Dataverse table column. Which two column data types can store numeric values? Each correct answer presents a complete solution.', 'teacher_john', 'teacher_john'),
    ('q_pl900_83', 'space_pl900_q01', 'single', 'What is the primary purpose of the Dataverse audit log?', 'teacher_john', 'teacher_john'),
    ('q_pl900_84', 'space_pl900_q01', 'single', 'A company needs to import data from an Excel file into a Dataverse table. Which tool should you use?', 'teacher_john', 'teacher_john'),
    ('q_pl900_85', 'space_pl900_q01', 'single', 'You need to restrict access to a specific column in a Dataverse table so only authorized users can view or edit it. Which Dataverse feature should you use?', 'teacher_john', 'teacher_john'),
    -- Copilot Studio (Q86–Q95)
    ('q_pl900_86', 'space_pl900_q01', 'single', 'What is the primary purpose of Microsoft Copilot Studio?', 'teacher_john', 'teacher_john'),
    ('q_pl900_87', 'space_pl900_q01', 'single', 'In Microsoft Copilot Studio, what is a topic?', 'teacher_john', 'teacher_john'),
    ('q_pl900_88', 'space_pl900_q01', 'multiple', 'You have built a copilot in Microsoft Copilot Studio. Which two channels can you publish the copilot to? Each correct answer presents a complete solution.', 'teacher_john', 'teacher_john'),
    ('q_pl900_89', 'space_pl900_q01', 'single', 'In Microsoft Copilot Studio, what is the purpose of entities?', 'teacher_john', 'teacher_john'),
    ('q_pl900_90', 'space_pl900_q01', 'single', 'A company wants to create a chatbot that answers frequently asked HR policy questions from employees. Which Microsoft Power Platform component should you use?', 'teacher_john', 'teacher_john'),
    ('q_pl900_91', 'space_pl900_q01', 'single', 'In Microsoft Copilot Studio, what happens when a user sends a message that does not match any defined topic trigger phrases?', 'teacher_john', 'teacher_john'),
    ('q_pl900_92', 'space_pl900_q01', 'single', 'You have a Microsoft Copilot Studio copilot. You need the copilot to retrieve live data from an external system in response to user questions. Which feature should you use?', 'teacher_john', 'teacher_john'),
    ('q_pl900_93', 'space_pl900_q01', 'single', 'What is the purpose of the test pane in Microsoft Copilot Studio?', 'teacher_john', 'teacher_john'),
    ('q_pl900_94', 'space_pl900_q01', 'single', 'A company uses a Copilot Studio copilot for customer support. Some complex inquiries need to be handed off to a human agent. Which node should you add to the copilot topic?', 'teacher_john', 'teacher_john'),
    ('q_pl900_95', 'space_pl900_q01', 'multiple', 'In Microsoft Copilot Studio, which two types of entities are available? Each correct answer presents a complete solution.', 'teacher_john', 'teacher_john'),
    -- AI Builder (Q96–Q100)
    ('q_pl900_96', 'space_pl900_q01', 'single', 'What is AI Builder in Microsoft Power Platform?', 'teacher_john', 'teacher_john'),
    ('q_pl900_97', 'space_pl900_q01', 'single', 'A company receives invoices as PDF files and needs to automatically extract fields such as invoice number, vendor name, and total amount. Which AI Builder model type should you use?', 'teacher_john', 'teacher_john'),
    ('q_pl900_98', 'space_pl900_q01', 'single', 'A company needs to automatically classify customer feedback as positive, negative, or neutral. Which AI Builder model should you use?', 'teacher_john', 'teacher_john'),
    ('q_pl900_99', 'space_pl900_q01', 'multiple', 'A company wants to use AI Builder without training a custom model. Which two prebuilt AI Builder models are available? Each correct answer presents a complete solution.', 'teacher_john', 'teacher_john'),
    ('q_pl900_100', 'space_pl900_q01', 'single', 'You create a custom AI Builder model. What must you do before you can use the model in a Power Apps app or Power Automate flow?', 'teacher_john', 'teacher_john')
ON CONFLICT (id) DO NOTHING;

INSERT INTO answers (id, question_id, text, is_correct, position, created_by, updated_by)
VALUES
    -- Q51: Workspace
    ('a_pl900_51_0', 'q_pl900_51', 'Dataset', FALSE, 0, 'teacher_john', 'teacher_john'),
    ('a_pl900_51_1', 'q_pl900_51', 'Workspace', TRUE, 1, 'teacher_john', 'teacher_john'),
    ('a_pl900_51_2', 'q_pl900_51', 'Gateway', FALSE, 2, 'teacher_john', 'teacher_john'),
    ('a_pl900_51_3', 'q_pl900_51', 'Power BI App', FALSE, 3, 'teacher_john', 'teacher_john'),
    -- Q52: Power BI Desktop
    ('a_pl900_52_0', 'q_pl900_52', 'Power BI Desktop', TRUE, 0, 'teacher_john', 'teacher_john'),
    ('a_pl900_52_1', 'q_pl900_52', 'Power BI service', FALSE, 1, 'teacher_john', 'teacher_john'),
    ('a_pl900_52_2', 'q_pl900_52', 'Power BI Mobile', FALSE, 2, 'teacher_john', 'teacher_john'),
    ('a_pl900_52_3', 'q_pl900_52', 'Power BI Embedded', FALSE, 3, 'teacher_john', 'teacher_john'),
    -- Q53: Dashboard
    ('a_pl900_53_0', 'q_pl900_53', 'A report', FALSE, 0, 'teacher_john', 'teacher_john'),
    ('a_pl900_53_1', 'q_pl900_53', 'A dashboard', TRUE, 1, 'teacher_john', 'teacher_john'),
    ('a_pl900_53_2', 'q_pl900_53', 'A dataset', FALSE, 2, 'teacher_john', 'teacher_john'),
    ('a_pl900_53_3', 'q_pl900_53', 'A dataflow', FALSE, 3, 'teacher_john', 'teacher_john'),
    -- Q54: Azure AD B2B guest access
    ('a_pl900_54_0', 'q_pl900_54', 'Power BI Embedded', FALSE, 0, 'teacher_john', 'teacher_john'),
    ('a_pl900_54_1', 'q_pl900_54', 'Power BI Premium only', FALSE, 1, 'teacher_john', 'teacher_john'),
    ('a_pl900_54_2', 'q_pl900_54', 'Azure Active Directory B2B guest access', TRUE, 2, 'teacher_john', 'teacher_john'),
    ('a_pl900_54_3', 'q_pl900_54', 'Publish to web (public)', FALSE, 3, 'teacher_john', 'teacher_john'),
    -- Q55: Line chart
    ('a_pl900_55_0', 'q_pl900_55', 'Bar chart', FALSE, 0, 'teacher_john', 'teacher_john'),
    ('a_pl900_55_1', 'q_pl900_55', 'Pie chart', FALSE, 1, 'teacher_john', 'teacher_john'),
    ('a_pl900_55_2', 'q_pl900_55', 'Line chart', TRUE, 2, 'teacher_john', 'teacher_john'),
    ('a_pl900_55_3', 'q_pl900_55', 'Scatter chart', FALSE, 3, 'teacher_john', 'teacher_john'),
    -- Q56: Scheduled refresh (requires on-premises data gateway)
    ('a_pl900_56_0', 'q_pl900_56', 'Install an on-premises data gateway and configure a scheduled refresh in the Power BI service', TRUE, 0, 'teacher_john', 'teacher_john'),
    ('a_pl900_56_1', 'q_pl900_56', 'Enable live connection mode in Power BI Desktop', FALSE, 1, 'teacher_john', 'teacher_john'),
    ('a_pl900_56_2', 'q_pl900_56', 'Publish the report to Power BI Embedded', FALSE, 2, 'teacher_john', 'teacher_john'),
    ('a_pl900_56_3', 'q_pl900_56', 'Configure a DLP policy in the Power Platform admin center', FALSE, 3, 'teacher_john', 'teacher_john'),
    -- Q57: Q&A
    ('a_pl900_57_0', 'q_pl900_57', 'Insights', FALSE, 0, 'teacher_john', 'teacher_john'),
    ('a_pl900_57_1', 'q_pl900_57', 'Q&A', TRUE, 1, 'teacher_john', 'teacher_john'),
    ('a_pl900_57_2', 'q_pl900_57', 'Bookmarks', FALSE, 2, 'teacher_john', 'teacher_john'),
    ('a_pl900_57_3', 'q_pl900_57', 'Dataflows', FALSE, 3, 'teacher_john', 'teacher_john'),
    -- Q58: Slicer
    ('a_pl900_58_0', 'q_pl900_58', 'Card', FALSE, 0, 'teacher_john', 'teacher_john'),
    ('a_pl900_58_1', 'q_pl900_58', 'Gauge', FALSE, 1, 'teacher_john', 'teacher_john'),
    ('a_pl900_58_2', 'q_pl900_58', 'Slicer', TRUE, 2, 'teacher_john', 'teacher_john'),
    ('a_pl900_58_3', 'q_pl900_58', 'KPI', FALSE, 3, 'teacher_john', 'teacher_john'),
    -- Q59: Bar chart + Column chart (multiple)
    ('a_pl900_59_0', 'q_pl900_59', 'Line chart', FALSE, 0, 'teacher_john', 'teacher_john'),
    ('a_pl900_59_1', 'q_pl900_59', 'Bar chart', TRUE, 1, 'teacher_john', 'teacher_john'),
    ('a_pl900_59_2', 'q_pl900_59', 'Pie chart', FALSE, 2, 'teacher_john', 'teacher_john'),
    ('a_pl900_59_3', 'q_pl900_59', 'Column chart', TRUE, 3, 'teacher_john', 'teacher_john'),
    ('a_pl900_59_4', 'q_pl900_59', 'Waterfall chart', FALSE, 4, 'teacher_john', 'teacher_john'),
    -- Q60: Power BI Pro
    ('a_pl900_60_0', 'q_pl900_60', 'Power BI Free', FALSE, 0, 'teacher_john', 'teacher_john'),
    ('a_pl900_60_1', 'q_pl900_60', 'Power BI Pro', TRUE, 1, 'teacher_john', 'teacher_john'),
    ('a_pl900_60_2', 'q_pl900_60', 'Microsoft 365 Basic', FALSE, 2, 'teacher_john', 'teacher_john'),
    ('a_pl900_60_3', 'q_pl900_60', 'Power BI Desktop license', FALSE, 3, 'teacher_john', 'teacher_john'),
    -- Q61: Power BI Embedded
    ('a_pl900_61_0', 'q_pl900_61', 'Power BI App', FALSE, 0, 'teacher_john', 'teacher_john'),
    ('a_pl900_61_1', 'q_pl900_61', 'Power BI Embedded', TRUE, 1, 'teacher_john', 'teacher_john'),
    ('a_pl900_61_2', 'q_pl900_61', 'Power BI Premium', FALSE, 2, 'teacher_john', 'teacher_john'),
    ('a_pl900_61_3', 'q_pl900_61', 'Power BI Mobile', FALSE, 3, 'teacher_john', 'teacher_john'),
    -- Q62: On-premises data gateway
    ('a_pl900_62_0', 'q_pl900_62', 'A Power BI Embedded license', FALSE, 0, 'teacher_john', 'teacher_john'),
    ('a_pl900_62_1', 'q_pl900_62', 'An on-premises data gateway', TRUE, 1, 'teacher_john', 'teacher_john'),
    ('a_pl900_62_2', 'q_pl900_62', 'A DLP policy', FALSE, 2, 'teacher_john', 'teacher_john'),
    ('a_pl900_62_3', 'q_pl900_62', 'A Power BI Pro license on the server', FALSE, 3, 'teacher_john', 'teacher_john'),
    -- Q63: Data alerts
    ('a_pl900_63_0', 'q_pl900_63', 'Scheduled refresh', FALSE, 0, 'teacher_john', 'teacher_john'),
    ('a_pl900_63_1', 'q_pl900_63', 'Data alerts', TRUE, 1, 'teacher_john', 'teacher_john'),
    ('a_pl900_63_2', 'q_pl900_63', 'Report subscriptions', FALSE, 2, 'teacher_john', 'teacher_john'),
    ('a_pl900_63_3', 'q_pl900_63', 'Q&A', FALSE, 3, 'teacher_john', 'teacher_john'),
    -- Q64: Power BI App
    ('a_pl900_64_0', 'q_pl900_64', 'A shared workspace', FALSE, 0, 'teacher_john', 'teacher_john'),
    ('a_pl900_64_1', 'q_pl900_64', 'A Power BI App', TRUE, 1, 'teacher_john', 'teacher_john'),
    ('a_pl900_64_2', 'q_pl900_64', 'A Power BI Embedded solution', FALSE, 2, 'teacher_john', 'teacher_john'),
    ('a_pl900_64_3', 'q_pl900_64', 'A dataflow', FALSE, 3, 'teacher_john', 'teacher_john'),
    -- Q65: Power BI Report Builder
    ('a_pl900_65_0', 'q_pl900_65', 'Power BI Desktop', FALSE, 0, 'teacher_john', 'teacher_john'),
    ('a_pl900_65_1', 'q_pl900_65', 'Power BI Report Builder', TRUE, 1, 'teacher_john', 'teacher_john'),
    ('a_pl900_65_2', 'q_pl900_65', 'Power BI Mobile', FALSE, 2, 'teacher_john', 'teacher_john'),
    ('a_pl900_65_3', 'q_pl900_65', 'Power BI service', FALSE, 3, 'teacher_john', 'teacher_john'),
    -- Q66: Automated trigger
    ('a_pl900_66_0', 'q_pl900_66', 'Scheduled trigger', FALSE, 0, 'teacher_john', 'teacher_john'),
    ('a_pl900_66_1', 'q_pl900_66', 'Automated trigger', TRUE, 1, 'teacher_john', 'teacher_john'),
    ('a_pl900_66_2', 'q_pl900_66', 'Manual trigger', FALSE, 2, 'teacher_john', 'teacher_john'),
    ('a_pl900_66_3', 'q_pl900_66', 'Instant trigger', FALSE, 3, 'teacher_john', 'teacher_john'),
    -- Q67: Start and wait for an approval
    ('a_pl900_67_0', 'q_pl900_67', 'Send an email (V2)', FALSE, 0, 'teacher_john', 'teacher_john'),
    ('a_pl900_67_1', 'q_pl900_67', 'Start and wait for an approval', TRUE, 1, 'teacher_john', 'teacher_john'),
    ('a_pl900_67_2', 'q_pl900_67', 'Create a Dataverse record', FALSE, 2, 'teacher_john', 'teacher_john'),
    ('a_pl900_67_3', 'q_pl900_67', 'Post a message to Teams', FALSE, 3, 'teacher_john', 'teacher_john'),
    -- Q68: Condition
    ('a_pl900_68_0', 'q_pl900_68', 'An Apply to each loop', FALSE, 0, 'teacher_john', 'teacher_john'),
    ('a_pl900_68_1', 'q_pl900_68', 'A condition', TRUE, 1, 'teacher_john', 'teacher_john'),
    ('a_pl900_68_2', 'q_pl900_68', 'A parallel branch', FALSE, 2, 'teacher_john', 'teacher_john'),
    ('a_pl900_68_3', 'q_pl900_68', 'A trigger', FALSE, 3, 'teacher_john', 'teacher_john'),
    -- Q69: Attended desktop flow
    ('a_pl900_69_0', 'q_pl900_69', 'Unattended', FALSE, 0, 'teacher_john', 'teacher_john'),
    ('a_pl900_69_1', 'q_pl900_69', 'Attended', TRUE, 1, 'teacher_john', 'teacher_john'),
    ('a_pl900_69_2', 'q_pl900_69', 'Scheduled cloud flow', FALSE, 2, 'teacher_john', 'teacher_john'),
    ('a_pl900_69_3', 'q_pl900_69', 'Automated cloud flow', FALSE, 3, 'teacher_john', 'teacher_john'),
    -- Q70: Custom connector
    ('a_pl900_70_0', 'q_pl900_70', 'A premium connector', FALSE, 0, 'teacher_john', 'teacher_john'),
    ('a_pl900_70_1', 'q_pl900_70', 'A custom connector', TRUE, 1, 'teacher_john', 'teacher_john'),
    ('a_pl900_70_2', 'q_pl900_70', 'An on-premises data gateway', FALSE, 2, 'teacher_john', 'teacher_john'),
    ('a_pl900_70_3', 'q_pl900_70', 'A standard connector', FALSE, 3, 'teacher_john', 'teacher_john'),
    -- Q71: Premium connector
    ('a_pl900_71_0', 'q_pl900_71', 'Standard', FALSE, 0, 'teacher_john', 'teacher_john'),
    ('a_pl900_71_1', 'q_pl900_71', 'Custom', FALSE, 1, 'teacher_john', 'teacher_john'),
    ('a_pl900_71_2', 'q_pl900_71', 'Premium', TRUE, 2, 'teacher_john', 'teacher_john'),
    ('a_pl900_71_3', 'q_pl900_71', 'Free', FALSE, 3, 'teacher_john', 'teacher_john'),
    -- Q72: Apply to each
    ('a_pl900_72_0', 'q_pl900_72', 'A condition', FALSE, 0, 'teacher_john', 'teacher_john'),
    ('a_pl900_72_1', 'q_pl900_72', 'An Apply to each loop', TRUE, 1, 'teacher_john', 'teacher_john'),
    ('a_pl900_72_2', 'q_pl900_72', 'A parallel branch', FALSE, 2, 'teacher_john', 'teacher_john'),
    ('a_pl900_72_3', 'q_pl900_72', 'A Do until loop', FALSE, 3, 'teacher_john', 'teacher_john'),
    -- Q73: Triggers + Actions (multiple)
    ('a_pl900_73_0', 'q_pl900_73', 'Triggers', TRUE, 0, 'teacher_john', 'teacher_john'),
    ('a_pl900_73_1', 'q_pl900_73', 'Security roles', FALSE, 1, 'teacher_john', 'teacher_john'),
    ('a_pl900_73_2', 'q_pl900_73', 'Actions', TRUE, 2, 'teacher_john', 'teacher_john'),
    ('a_pl900_73_3', 'q_pl900_73', 'Formulas', FALSE, 3, 'teacher_john', 'teacher_john'),
    ('a_pl900_73_4', 'q_pl900_73', 'Environments', FALSE, 4, 'teacher_john', 'teacher_john'),
    -- Q74: Unattended desktop flow
    ('a_pl900_74_0', 'q_pl900_74', 'Attended', FALSE, 0, 'teacher_john', 'teacher_john'),
    ('a_pl900_74_1', 'q_pl900_74', 'Unattended', TRUE, 1, 'teacher_john', 'teacher_john'),
    ('a_pl900_74_2', 'q_pl900_74', 'Instant cloud flow', FALSE, 2, 'teacher_john', 'teacher_john'),
    ('a_pl900_74_3', 'q_pl900_74', 'Scheduled cloud flow', FALSE, 3, 'teacher_john', 'teacher_john'),
    -- Q75: Run after
    ('a_pl900_75_0', 'q_pl900_75', 'Concurrency control', FALSE, 0, 'teacher_john', 'teacher_john'),
    ('a_pl900_75_1', 'q_pl900_75', 'Run after settings', TRUE, 1, 'teacher_john', 'teacher_john'),
    ('a_pl900_75_2', 'q_pl900_75', 'Retry policy', FALSE, 2, 'teacher_john', 'teacher_john'),
    ('a_pl900_75_3', 'q_pl900_75', 'Timeout settings', FALSE, 3, 'teacher_john', 'teacher_john'),
    -- Q76: Security role
    ('a_pl900_76_0', 'q_pl900_76', 'To define the columns in a Dataverse table', FALSE, 0, 'teacher_john', 'teacher_john'),
    ('a_pl900_76_1', 'q_pl900_76', 'To control user access to tables and records in Dataverse', TRUE, 1, 'teacher_john', 'teacher_john'),
    ('a_pl900_76_2', 'q_pl900_76', 'To automate data entry in a canvas app', FALSE, 2, 'teacher_john', 'teacher_john'),
    ('a_pl900_76_3', 'q_pl900_76', 'To create relationships between Dataverse tables', FALSE, 3, 'teacher_john', 'teacher_john'),
    -- Q77: Rollup column
    ('a_pl900_77_0', 'q_pl900_77', 'Calculated column', FALSE, 0, 'teacher_john', 'teacher_john'),
    ('a_pl900_77_1', 'q_pl900_77', 'Rollup column', TRUE, 1, 'teacher_john', 'teacher_john'),
    ('a_pl900_77_2', 'q_pl900_77', 'Lookup column', FALSE, 2, 'teacher_john', 'teacher_john'),
    ('a_pl900_77_3', 'q_pl900_77', 'Choice column', FALSE, 3, 'teacher_john', 'teacher_john'),
    -- Q78: Auditing
    ('a_pl900_78_0', 'q_pl900_78', 'Change tracking', FALSE, 0, 'teacher_john', 'teacher_john'),
    ('a_pl900_78_1', 'q_pl900_78', 'Auditing', TRUE, 1, 'teacher_john', 'teacher_john'),
    ('a_pl900_78_2', 'q_pl900_78', 'Business rules', FALSE, 2, 'teacher_john', 'teacher_john'),
    ('a_pl900_78_3', 'q_pl900_78', 'Duplicate detection', FALSE, 3, 'teacher_john', 'teacher_john'),
    -- Q79: Container for resources
    ('a_pl900_79_0', 'q_pl900_79', 'A type of Power Apps canvas app', FALSE, 0, 'teacher_john', 'teacher_john'),
    ('a_pl900_79_1', 'q_pl900_79', 'A container that stores apps, flows, data, and other Power Platform resources', TRUE, 1, 'teacher_john', 'teacher_john'),
    ('a_pl900_79_2', 'q_pl900_79', 'A type of Power BI report', FALSE, 2, 'teacher_john', 'teacher_john'),
    ('a_pl900_79_3', 'q_pl900_79', 'A security role for Dataverse tables', FALSE, 3, 'teacher_john', 'teacher_john'),
    -- Q80: Business rule
    ('a_pl900_80_0', 'q_pl900_80', 'A server-side plug-in', FALSE, 0, 'teacher_john', 'teacher_john'),
    ('a_pl900_80_1', 'q_pl900_80', 'A business rule', TRUE, 1, 'teacher_john', 'teacher_john'),
    ('a_pl900_80_2', 'q_pl900_80', 'A Power Automate cloud flow', FALSE, 2, 'teacher_john', 'teacher_john'),
    ('a_pl900_80_3', 'q_pl900_80', 'A calculated column', FALSE, 3, 'teacher_john', 'teacher_john'),
    -- Q81: Solution
    ('a_pl900_81_0', 'q_pl900_81', 'A Power BI app', FALSE, 0, 'teacher_john', 'teacher_john'),
    ('a_pl900_81_1', 'q_pl900_81', 'A Dataverse table export', FALSE, 1, 'teacher_john', 'teacher_john'),
    ('a_pl900_81_2', 'q_pl900_81', 'A Power Platform solution', TRUE, 2, 'teacher_john', 'teacher_john'),
    ('a_pl900_81_3', 'q_pl900_81', 'A Power Pages site', FALSE, 3, 'teacher_john', 'teacher_john'),
    -- Q82: Whole Number + Currency (multiple)
    ('a_pl900_82_0', 'q_pl900_82', 'Whole Number', TRUE, 0, 'teacher_john', 'teacher_john'),
    ('a_pl900_82_1', 'q_pl900_82', 'Text', FALSE, 1, 'teacher_john', 'teacher_john'),
    ('a_pl900_82_2', 'q_pl900_82', 'Currency', TRUE, 2, 'teacher_john', 'teacher_john'),
    ('a_pl900_82_3', 'q_pl900_82', 'Choice', FALSE, 3, 'teacher_john', 'teacher_john'),
    ('a_pl900_82_4', 'q_pl900_82', 'File', FALSE, 4, 'teacher_john', 'teacher_john'),
    -- Q83: Audit log purpose
    ('a_pl900_83_0', 'q_pl900_83', 'To store user passwords securely', FALSE, 0, 'teacher_john', 'teacher_john'),
    ('a_pl900_83_1', 'q_pl900_83', 'To track changes to records for compliance and security purposes', TRUE, 1, 'teacher_john', 'teacher_john'),
    ('a_pl900_83_2', 'q_pl900_83', 'To define business rules on tables', FALSE, 2, 'teacher_john', 'teacher_john'),
    ('a_pl900_83_3', 'q_pl900_83', 'To create table relationships', FALSE, 3, 'teacher_john', 'teacher_john'),
    -- Q84: Data import wizard
    ('a_pl900_84_0', 'q_pl900_84', 'Power BI Desktop', FALSE, 0, 'teacher_john', 'teacher_john'),
    ('a_pl900_84_1', 'q_pl900_84', 'The data import wizard in the Power Apps maker portal', TRUE, 1, 'teacher_john', 'teacher_john'),
    ('a_pl900_84_2', 'q_pl900_84', 'Power Automate desktop flow', FALSE, 2, 'teacher_john', 'teacher_john'),
    ('a_pl900_84_3', 'q_pl900_84', 'Power Pages', FALSE, 3, 'teacher_john', 'teacher_john'),
    -- Q85: Field security profiles
    ('a_pl900_85_0', 'q_pl900_85', 'Security roles', FALSE, 0, 'teacher_john', 'teacher_john'),
    ('a_pl900_85_1', 'q_pl900_85', 'Field security profiles', TRUE, 1, 'teacher_john', 'teacher_john'),
    ('a_pl900_85_2', 'q_pl900_85', 'Business rules', FALSE, 2, 'teacher_john', 'teacher_john'),
    ('a_pl900_85_3', 'q_pl900_85', 'Managed properties', FALSE, 3, 'teacher_john', 'teacher_john'),
    -- Q86: Copilot Studio purpose
    ('a_pl900_86_0', 'q_pl900_86', 'To create Power BI reports', FALSE, 0, 'teacher_john', 'teacher_john'),
    ('a_pl900_86_1', 'q_pl900_86', 'To build and deploy conversational AI chatbots and copilots', TRUE, 1, 'teacher_john', 'teacher_john'),
    ('a_pl900_86_2', 'q_pl900_86', 'To automate desktop applications', FALSE, 2, 'teacher_john', 'teacher_john'),
    ('a_pl900_86_3', 'q_pl900_86', 'To create canvas apps', FALSE, 3, 'teacher_john', 'teacher_john'),
    -- Q87: Topic
    ('a_pl900_87_0', 'q_pl900_87', 'A data source for a copilot', FALSE, 0, 'teacher_john', 'teacher_john'),
    ('a_pl900_87_1', 'q_pl900_87', 'A set of conversation nodes that define how the copilot responds to specific user input', TRUE, 1, 'teacher_john', 'teacher_john'),
    ('a_pl900_87_2', 'q_pl900_87', 'A type of connector', FALSE, 2, 'teacher_john', 'teacher_john'),
    ('a_pl900_87_3', 'q_pl900_87', 'A security role for copilots', FALSE, 3, 'teacher_john', 'teacher_john'),
    -- Q88: Publish channels (multiple) - Teams + custom website
    ('a_pl900_88_0', 'q_pl900_88', 'Microsoft Teams', TRUE, 0, 'teacher_john', 'teacher_john'),
    ('a_pl900_88_1', 'q_pl900_88', 'Power BI', FALSE, 1, 'teacher_john', 'teacher_john'),
    ('a_pl900_88_2', 'q_pl900_88', 'A custom website', TRUE, 2, 'teacher_john', 'teacher_john'),
    ('a_pl900_88_3', 'q_pl900_88', 'Microsoft Dataverse', FALSE, 3, 'teacher_john', 'teacher_john'),
    ('a_pl900_88_4', 'q_pl900_88', 'Azure DevOps', FALSE, 4, 'teacher_john', 'teacher_john'),
    -- Q89: Entities
    ('a_pl900_89_0', 'q_pl900_89', 'To define the visual appearance of the copilot', FALSE, 0, 'teacher_john', 'teacher_john'),
    ('a_pl900_89_1', 'q_pl900_89', 'To identify and extract specific types of information from user input', TRUE, 1, 'teacher_john', 'teacher_john'),
    ('a_pl900_89_2', 'q_pl900_89', 'To authenticate users in the copilot', FALSE, 2, 'teacher_john', 'teacher_john'),
    ('a_pl900_89_3', 'q_pl900_89', 'To store conversation history', FALSE, 3, 'teacher_john', 'teacher_john'),
    -- Q90: HR chatbot = Copilot Studio
    ('a_pl900_90_0', 'q_pl900_90', 'Power Apps', FALSE, 0, 'teacher_john', 'teacher_john'),
    ('a_pl900_90_1', 'q_pl900_90', 'Power Automate', FALSE, 1, 'teacher_john', 'teacher_john'),
    ('a_pl900_90_2', 'q_pl900_90', 'Power BI', FALSE, 2, 'teacher_john', 'teacher_john'),
    ('a_pl900_90_3', 'q_pl900_90', 'Microsoft Copilot Studio', TRUE, 3, 'teacher_john', 'teacher_john'),
    -- Q91: Fallback topic
    ('a_pl900_91_0', 'q_pl900_91', 'The copilot ends the conversation', FALSE, 0, 'teacher_john', 'teacher_john'),
    ('a_pl900_91_1', 'q_pl900_91', 'The copilot triggers the system fallback topic', TRUE, 1, 'teacher_john', 'teacher_john'),
    ('a_pl900_91_2', 'q_pl900_91', 'The copilot redirects to Power Automate', FALSE, 2, 'teacher_john', 'teacher_john'),
    ('a_pl900_91_3', 'q_pl900_91', 'The copilot creates a new topic automatically', FALSE, 3, 'teacher_john', 'teacher_john'),
    -- Q92: Power Automate flow action in copilot
    ('a_pl900_92_0', 'q_pl900_92', 'A topic', FALSE, 0, 'teacher_john', 'teacher_john'),
    ('a_pl900_92_1', 'q_pl900_92', 'An entity', FALSE, 1, 'teacher_john', 'teacher_john'),
    ('a_pl900_92_2', 'q_pl900_92', 'A Power Automate flow action', TRUE, 2, 'teacher_john', 'teacher_john'),
    ('a_pl900_92_3', 'q_pl900_92', 'A variable', FALSE, 3, 'teacher_john', 'teacher_john'),
    -- Q93: Test pane
    ('a_pl900_93_0', 'q_pl900_93', 'To publish the copilot to all configured channels', FALSE, 0, 'teacher_john', 'teacher_john'),
    ('a_pl900_93_1', 'q_pl900_93', 'To test the copilot''s conversation flow interactively before publishing', TRUE, 1, 'teacher_john', 'teacher_john'),
    ('a_pl900_93_2', 'q_pl900_93', 'To manage security roles for the copilot', FALSE, 2, 'teacher_john', 'teacher_john'),
    ('a_pl900_93_3', 'q_pl900_93', 'To configure Power Automate flow integrations', FALSE, 3, 'teacher_john', 'teacher_john'),
    -- Q94: Transfer to agent node
    ('a_pl900_94_0', 'q_pl900_94', 'A fallback topic', FALSE, 0, 'teacher_john', 'teacher_john'),
    ('a_pl900_94_1', 'q_pl900_94', 'The Transfer to agent node in an escalation topic', TRUE, 1, 'teacher_john', 'teacher_john'),
    ('a_pl900_94_2', 'q_pl900_94', 'A Power Automate cloud flow', FALSE, 2, 'teacher_john', 'teacher_john'),
    ('a_pl900_94_3', 'q_pl900_94', 'An entity', FALSE, 3, 'teacher_john', 'teacher_john'),
    -- Q95: Prebuilt + Custom entities (multiple)
    ('a_pl900_95_0', 'q_pl900_95', 'Prebuilt entities', TRUE, 0, 'teacher_john', 'teacher_john'),
    ('a_pl900_95_1', 'q_pl900_95', 'Flow entities', FALSE, 1, 'teacher_john', 'teacher_john'),
    ('a_pl900_95_2', 'q_pl900_95', 'Custom entities', TRUE, 2, 'teacher_john', 'teacher_john'),
    ('a_pl900_95_3', 'q_pl900_95', 'Connector entities', FALSE, 3, 'teacher_john', 'teacher_john'),
    ('a_pl900_95_4', 'q_pl900_95', 'Table entities', FALSE, 4, 'teacher_john', 'teacher_john'),
    -- Q96: AI Builder purpose
    ('a_pl900_96_0', 'q_pl900_96', 'A tool for building canvas apps without code', FALSE, 0, 'teacher_john', 'teacher_john'),
    ('a_pl900_96_1', 'q_pl900_96', 'A feature that adds AI capabilities to Power Apps and Power Automate', TRUE, 1, 'teacher_john', 'teacher_john'),
    ('a_pl900_96_2', 'q_pl900_96', 'A type of Dataverse standard table', FALSE, 2, 'teacher_john', 'teacher_john'),
    ('a_pl900_96_3', 'q_pl900_96', 'A Power BI visualization type', FALSE, 3, 'teacher_john', 'teacher_john'),
    -- Q97: Document processing
    ('a_pl900_97_0', 'q_pl900_97', 'Text classification', FALSE, 0, 'teacher_john', 'teacher_john'),
    ('a_pl900_97_1', 'q_pl900_97', 'Object detection', FALSE, 1, 'teacher_john', 'teacher_john'),
    ('a_pl900_97_2', 'q_pl900_97', 'Document processing', TRUE, 2, 'teacher_john', 'teacher_john'),
    ('a_pl900_97_3', 'q_pl900_97', 'Prediction', FALSE, 3, 'teacher_john', 'teacher_john'),
    -- Q98: Text classification
    ('a_pl900_98_0', 'q_pl900_98', 'Object detection', FALSE, 0, 'teacher_john', 'teacher_john'),
    ('a_pl900_98_1', 'q_pl900_98', 'Text classification', TRUE, 1, 'teacher_john', 'teacher_john'),
    ('a_pl900_98_2', 'q_pl900_98', 'Document processing', FALSE, 2, 'teacher_john', 'teacher_john'),
    ('a_pl900_98_3', 'q_pl900_98', 'Prediction', FALSE, 3, 'teacher_john', 'teacher_john'),
    -- Q99: Prebuilt models (multiple) - Sentiment analysis + Business card reader
    ('a_pl900_99_0', 'q_pl900_99', 'Sentiment analysis', TRUE, 0, 'teacher_john', 'teacher_john'),
    ('a_pl900_99_1', 'q_pl900_99', 'Object detection (custom)', FALSE, 1, 'teacher_john', 'teacher_john'),
    ('a_pl900_99_2', 'q_pl900_99', 'Business card reader', TRUE, 2, 'teacher_john', 'teacher_john'),
    ('a_pl900_99_3', 'q_pl900_99', 'Prediction (custom)', FALSE, 3, 'teacher_john', 'teacher_john'),
    ('a_pl900_99_4', 'q_pl900_99', 'Text classification (custom)', FALSE, 4, 'teacher_john', 'teacher_john'),
    -- Q100: Train and publish
    ('a_pl900_100_0', 'q_pl900_100', 'Deploy the model to Azure Machine Learning', FALSE, 0, 'teacher_john', 'teacher_john'),
    ('a_pl900_100_1', 'q_pl900_100', 'Publish the model without training', FALSE, 1, 'teacher_john', 'teacher_john'),
    ('a_pl900_100_2', 'q_pl900_100', 'Train and publish the model', TRUE, 2, 'teacher_john', 'teacher_john'),
    ('a_pl900_100_3', 'q_pl900_100', 'Export the model to Power BI', FALSE, 3, 'teacher_john', 'teacher_john')
ON CONFLICT (id) DO NOTHING;

INSERT INTO questions (id, space_id, question_type, body, created_by, updated_by)
VALUES
    -- Power Platform general (Q101–Q110)
    ('q_pl900_101', 'space_pl900_q01', 'single', 'What is the purpose of a Data Loss Prevention (DLP) policy in Microsoft Power Platform?', 'teacher_john', 'teacher_john'),
    ('q_pl900_102', 'space_pl900_q01', 'single', 'A company wants to create a Power Platform environment for user acceptance testing that can be reset or deleted without affecting production. Which environment type should you use?', 'teacher_john', 'teacher_john'),
    ('q_pl900_103', 'space_pl900_q01', 'single', 'A company''s IT team wants greater control over Power Platform adoption including enforced solution checker, weekly digest emails, and usage insights. Which feature should they enable?', 'teacher_john', 'teacher_john'),
    ('q_pl900_104', 'space_pl900_q01', 'single', 'In Microsoft Power Platform, what is a connector?', 'teacher_john', 'teacher_john'),
    ('q_pl900_105', 'space_pl900_q01', 'multiple', 'Which two categories of Microsoft-provided connectors exist in Power Platform? Each correct answer presents a complete solution.', 'teacher_john', 'teacher_john'),
    ('q_pl900_106', 'space_pl900_q01', 'single', 'Which tool provides Power Platform administrators with a central location to manage environments, DLP policies, capacity, and licensing?', 'teacher_john', 'teacher_john'),
    ('q_pl900_107', 'space_pl900_q01', 'single', 'What is the Microsoft Power Platform Center of Excellence (CoE) Starter Kit?', 'teacher_john', 'teacher_john'),
    ('q_pl900_108', 'space_pl900_q01', 'single', 'A Power Platform administrator needs to view and manage all Power Automate flows across the entire organization, not just their own flows. Where should the administrator go?', 'teacher_john', 'teacher_john'),
    ('q_pl900_109', 'space_pl900_q01', 'single', 'You need to move Power Platform components from a development environment to a production environment. What should you use?', 'teacher_john', 'teacher_john'),
    ('q_pl900_110', 'space_pl900_q01', 'single', 'A company wants to analyze the impact of a Power Platform solution on existing components before deploying. What should you run?', 'teacher_john', 'teacher_john'),
    -- Scenario-based mixed (Q111–Q120)
    ('q_pl900_111', 'space_pl900_q01', 'single', 'A user reports that a canvas app shows no data from a Dataverse table, even though the table contains records. What is the most likely cause?', 'teacher_john', 'teacher_john'),
    ('q_pl900_112', 'space_pl900_q01', 'single', 'You need to create a Power BI visualization that shows total sales distributed across geographic regions on a map. Which visualization type should you use?', 'teacher_john', 'teacher_john'),
    ('q_pl900_113', 'space_pl900_q01', 'single', 'A company needs to automatically classify incoming documents into categories such as invoices, contracts, and purchase orders. Which Power Platform component should you use?', 'teacher_john', 'teacher_john'),
    ('q_pl900_114', 'space_pl900_q01', 'single', 'You have a canvas app with two screens. You need to navigate from Screen1 to Screen2 when a button is tapped. Which formula should you use in the button''s OnSelect property?', 'teacher_john', 'teacher_john'),
    ('q_pl900_115', 'space_pl900_q01', 'single', 'A company needs to export data from a Dataverse table to a SharePoint list automatically every weekday at 8 AM. Which approach should you use?', 'teacher_john', 'teacher_john'),
    ('q_pl900_116', 'space_pl900_q01', 'single', 'You need to create a Microsoft Copilot Studio copilot that answers questions about company policies by searching content stored in SharePoint. Which Copilot Studio feature should you enable?', 'teacher_john', 'teacher_john'),
    ('q_pl900_117', 'space_pl900_q01', 'single', 'A company needs to prevent users from combining SharePoint connectors with social media connectors in Power Automate flows. What should you configure?', 'teacher_john', 'teacher_john'),
    ('q_pl900_118', 'space_pl900_q01', 'single', 'You have a Dataverse table named Projects. You need a column that automatically computes a value using a formula based on other columns in the same record. Which column type should you create?', 'teacher_john', 'teacher_john'),
    ('q_pl900_119', 'space_pl900_q01', 'single', 'A company has a Power Pages site. They need external users to sign in using their Microsoft accounts. What should you configure?', 'teacher_john', 'teacher_john'),
    ('q_pl900_120', 'space_pl900_q01', 'single', 'You have a Power Platform solution and need to analyze it for potential issues and best practice violations before deploying to production. What should you run?', 'teacher_john', 'teacher_john'),
    -- Power Apps deeper (Q121–Q130)
    ('q_pl900_121', 'space_pl900_q01', 'single', 'What is the key difference between a canvas app and a model-driven app in Power Apps?', 'teacher_john', 'teacher_john'),
    ('q_pl900_122', 'space_pl900_q01', 'single', 'You are building a model-driven app. Which component defines the layout of fields displayed when a user opens a Dataverse record?', 'teacher_john', 'teacher_john'),
    ('q_pl900_123', 'space_pl900_q01', 'single', 'You are building a canvas app that needs to display a scrollable list of products from a Dataverse table. Which canvas app control should you use?', 'teacher_john', 'teacher_john'),
    ('q_pl900_124', 'space_pl900_q01', 'single', 'A developer needs to execute custom server-side business logic automatically when a Dataverse record is created or updated. Which Dataverse feature should they use?', 'teacher_john', 'teacher_john'),
    ('q_pl900_125', 'space_pl900_q01', 'single', 'You need to create a Power Automate flow that starts when an item in a SharePoint list is modified. Which trigger should you use?', 'teacher_john', 'teacher_john'),
    ('q_pl900_126', 'space_pl900_q01', 'single', 'What is the purpose of a Power BI App?', 'teacher_john', 'teacher_john'),
    ('q_pl900_127', 'space_pl900_q01', 'single', 'A company needs to track customer service cases and agent interactions, with a guided process for agents. Which Power Platform solution is most appropriate?', 'teacher_john', 'teacher_john'),
    ('q_pl900_128', 'space_pl900_q01', 'single', 'What is a managed solution in Microsoft Power Platform?', 'teacher_john', 'teacher_john'),
    ('q_pl900_129', 'space_pl900_q01', 'multiple', 'A company receives PDF invoices by email and needs to extract data and store it in Dataverse automatically. Which two Power Platform components should you use? Each correct answer presents a complete solution.', 'teacher_john', 'teacher_john'),
    ('q_pl900_130', 'space_pl900_q01', 'single', 'You have multiple Power BI reports in a workspace. You need a single-page view that combines key visuals from all of them. What should you do?', 'teacher_john', 'teacher_john'),
    -- Mixed advanced (Q131–Q140)
    ('q_pl900_131', 'space_pl900_q01', 'single', 'In a model-driven Power App, what is the purpose of a view?', 'teacher_john', 'teacher_john'),
    ('q_pl900_132', 'space_pl900_q01', 'single', 'You need to connect a canvas app to a third-party service that has a REST API but no existing Power Platform connector. What should you create?', 'teacher_john', 'teacher_john'),
    ('q_pl900_133', 'space_pl900_q01', 'single', 'You are creating a Power BI report from an Azure SQL database. What is the first step you should perform in Power BI Desktop?', 'teacher_john', 'teacher_john'),
    ('q_pl900_134', 'space_pl900_q01', 'single', 'You need to create a Power Automate flow that runs every Monday at 9 AM. Which trigger type should you use?', 'teacher_john', 'teacher_john'),
    ('q_pl900_135', 'space_pl900_q01', 'single', 'You have a Microsoft Copilot Studio copilot published to a custom website. You need to add the copilot to a Microsoft Teams channel as well. What should you configure in Copilot Studio?', 'teacher_john', 'teacher_john'),
    ('q_pl900_136', 'space_pl900_q01', 'single', 'A company needs to ensure that users can only see Dataverse records that they own and not records owned by others. Which mechanism controls this?', 'teacher_john', 'teacher_john'),
    ('q_pl900_137', 'space_pl900_q01', 'single', 'You need to create a Power Automate flow that starts whenever a new record is added to a Dataverse table. Which type of flow should you create?', 'teacher_john', 'teacher_john'),
    ('q_pl900_138', 'space_pl900_q01', 'single', 'A Power Pages site needs to support authentication via social identity providers such as LinkedIn and Facebook. Which Power Pages feature enables this?', 'teacher_john', 'teacher_john'),
    ('q_pl900_139', 'space_pl900_q01', 'single', 'What is the purpose of the Microsoft Dataverse Web API?', 'teacher_john', 'teacher_john'),
    ('q_pl900_140', 'space_pl900_q01', 'multiple', 'You need to identify two Power Platform components that can use Microsoft Dataverse as a data source. Which two should you identify? Each correct answer presents a complete solution.', 'teacher_john', 'teacher_john'),
    -- Final batch (Q141–Q150)
    ('q_pl900_141', 'space_pl900_q01', 'single', 'Which type of Power Platform environment cannot be deleted and is automatically created for every tenant?', 'teacher_john', 'teacher_john'),
    ('q_pl900_142', 'space_pl900_q01', 'single', 'You need to add an AI Builder document processing model to a Power Automate flow. What must you do before the model is available for use?', 'teacher_john', 'teacher_john'),
    ('q_pl900_143', 'space_pl900_q01', 'single', 'Which Power Platform feature allows makers to create apps with minimal coding by using a browser-based visual designer?', 'teacher_john', 'teacher_john'),
    ('q_pl900_144', 'space_pl900_q01', 'single', 'You have a Power Automate cloud flow that calls an external API. The API occasionally returns transient errors. You need the flow to automatically retry the call up to three times. What should you configure on the action?', 'teacher_john', 'teacher_john'),
    ('q_pl900_145', 'space_pl900_q01', 'single', 'A company wants to create a sandbox Power Platform environment for developers to test preview features. The environment must not affect the production environment. Which environment type should you create?', 'teacher_john', 'teacher_john'),
    ('q_pl900_146', 'space_pl900_q01', 'single', 'You have a canvas app. You need to format a numeric value as currency with two decimal places. Which Power Apps function should you use?', 'teacher_john', 'teacher_john'),
    ('q_pl900_147', 'space_pl900_q01', 'single', 'A company uses Power Pages for a customer portal. Customers must be able to sign in and view their own Dataverse records but not other customers'' records. Which Power Pages feature controls record-level access?', 'teacher_john', 'teacher_john'),
    ('q_pl900_148', 'space_pl900_q01', 'multiple', 'You are building a canvas app and need to allow users to select one or more items from a list. Which two controls support multi-selection? Each correct answer presents a complete solution.', 'teacher_john', 'teacher_john'),
    ('q_pl900_149', 'space_pl900_q01', 'single', 'A company needs to monitor Power Platform storage capacity and user activity across all environments from a single location. Which tool should you use?', 'teacher_john', 'teacher_john'),
    ('q_pl900_150', 'space_pl900_q01', 'single', 'You have a Power Apps model-driven app connected to Dataverse. You need to enable all users in the organization to access the app. What should you do?', 'teacher_john', 'teacher_john')
ON CONFLICT (id) DO NOTHING;

INSERT INTO answers (id, question_id, text, is_correct, position, created_by, updated_by)
VALUES
    -- Q101: DLP policy
    ('a_pl900_101_0', 'q_pl900_101', 'To prevent unauthorized users from accessing Power Platform environments', FALSE, 0, 'teacher_john', 'teacher_john'),
    ('a_pl900_101_1', 'q_pl900_101', 'To classify connectors into groups to prevent data from flowing between them inappropriately', TRUE, 1, 'teacher_john', 'teacher_john'),
    ('a_pl900_101_2', 'q_pl900_101', 'To encrypt data stored in Microsoft Dataverse', FALSE, 2, 'teacher_john', 'teacher_john'),
    ('a_pl900_101_3', 'q_pl900_101', 'To manage Power Apps per-user licensing', FALSE, 3, 'teacher_john', 'teacher_john'),
    -- Q102: Sandbox environment
    ('a_pl900_102_0', 'q_pl900_102', 'Default', FALSE, 0, 'teacher_john', 'teacher_john'),
    ('a_pl900_102_1', 'q_pl900_102', 'Sandbox', TRUE, 1, 'teacher_john', 'teacher_john'),
    ('a_pl900_102_2', 'q_pl900_102', 'Trial', FALSE, 2, 'teacher_john', 'teacher_john'),
    ('a_pl900_102_3', 'q_pl900_102', 'Developer', FALSE, 3, 'teacher_john', 'teacher_john'),
    -- Q103: Managed environment
    ('a_pl900_103_0', 'q_pl900_103', 'Developer environment', FALSE, 0, 'teacher_john', 'teacher_john'),
    ('a_pl900_103_1', 'q_pl900_103', 'Managed environment', TRUE, 1, 'teacher_john', 'teacher_john'),
    ('a_pl900_103_2', 'q_pl900_103', 'Default environment', FALSE, 2, 'teacher_john', 'teacher_john'),
    ('a_pl900_103_3', 'q_pl900_103', 'Trial environment', FALSE, 3, 'teacher_john', 'teacher_john'),
    -- Q104: Connector definition
    ('a_pl900_104_0', 'q_pl900_104', 'A type of Dataverse virtual table', FALSE, 0, 'teacher_john', 'teacher_john'),
    ('a_pl900_104_1', 'q_pl900_104', 'A proxy that allows Power Apps and Power Automate to communicate with external services and APIs', TRUE, 1, 'teacher_john', 'teacher_john'),
    ('a_pl900_104_2', 'q_pl900_104', 'A canvas app control for displaying data', FALSE, 2, 'teacher_john', 'teacher_john'),
    ('a_pl900_104_3', 'q_pl900_104', 'A Dataverse security role', FALSE, 3, 'teacher_john', 'teacher_john'),
    -- Q105: Standard + Premium connectors (multiple)
    ('a_pl900_105_0', 'q_pl900_105', 'Standard', TRUE, 0, 'teacher_john', 'teacher_john'),
    ('a_pl900_105_1', 'q_pl900_105', 'Legacy', FALSE, 1, 'teacher_john', 'teacher_john'),
    ('a_pl900_105_2', 'q_pl900_105', 'Premium', TRUE, 2, 'teacher_john', 'teacher_john'),
    ('a_pl900_105_3', 'q_pl900_105', 'Enterprise', FALSE, 3, 'teacher_john', 'teacher_john'),
    ('a_pl900_105_4', 'q_pl900_105', 'Professional', FALSE, 4, 'teacher_john', 'teacher_john'),
    -- Q106: Power Platform admin center
    ('a_pl900_106_0', 'q_pl900_106', 'Power Apps Studio', FALSE, 0, 'teacher_john', 'teacher_john'),
    ('a_pl900_106_1', 'q_pl900_106', 'Power BI Desktop', FALSE, 1, 'teacher_john', 'teacher_john'),
    ('a_pl900_106_2', 'q_pl900_106', 'Power Platform admin center', TRUE, 2, 'teacher_john', 'teacher_john'),
    ('a_pl900_106_3', 'q_pl900_106', 'Microsoft 365 admin center', FALSE, 3, 'teacher_john', 'teacher_john'),
    -- Q107: CoE Starter Kit
    ('a_pl900_107_0', 'q_pl900_107', 'A set of Power BI templates for financial reporting', FALSE, 0, 'teacher_john', 'teacher_john'),
    ('a_pl900_107_1', 'q_pl900_107', 'A collection of components and tools that help organizations govern and manage their Power Platform adoption', TRUE, 1, 'teacher_john', 'teacher_john'),
    ('a_pl900_107_2', 'q_pl900_107', 'A premium Power Apps license tier', FALSE, 2, 'teacher_john', 'teacher_john'),
    ('a_pl900_107_3', 'q_pl900_107', 'A set of Dataverse templates for HR management', FALSE, 3, 'teacher_john', 'teacher_john'),
    -- Q108: Admin center for org-wide flows
    ('a_pl900_108_0', 'q_pl900_108', 'Power Apps maker portal under My flows', FALSE, 0, 'teacher_john', 'teacher_john'),
    ('a_pl900_108_1', 'q_pl900_108', 'Power Automate > My flows', FALSE, 1, 'teacher_john', 'teacher_john'),
    ('a_pl900_108_2', 'q_pl900_108', 'The Power Platform admin center', TRUE, 2, 'teacher_john', 'teacher_john'),
    ('a_pl900_108_3', 'q_pl900_108', 'Power BI service', FALSE, 3, 'teacher_john', 'teacher_john'),
    -- Q109: Export/import solution
    ('a_pl900_109_0', 'q_pl900_109', 'Copy the development environment to production', FALSE, 0, 'teacher_john', 'teacher_john'),
    ('a_pl900_109_1', 'q_pl900_109', 'Export the solution from development and import it into production', TRUE, 1, 'teacher_john', 'teacher_john'),
    ('a_pl900_109_2', 'q_pl900_109', 'Manually recreate all components in the production environment', FALSE, 2, 'teacher_john', 'teacher_john'),
    ('a_pl900_109_3', 'q_pl900_109', 'Use Power BI to migrate the data', FALSE, 3, 'teacher_john', 'teacher_john'),
    -- Q110: Solution checker
    ('a_pl900_110_0', 'q_pl900_110', 'Dependency checker', FALSE, 0, 'teacher_john', 'teacher_john'),
    ('a_pl900_110_1', 'q_pl900_110', 'Solution checker', TRUE, 1, 'teacher_john', 'teacher_john'),
    ('a_pl900_110_2', 'q_pl900_110', 'Environment comparison tool', FALSE, 2, 'teacher_john', 'teacher_john'),
    ('a_pl900_110_3', 'q_pl900_110', 'Managed properties validator', FALSE, 3, 'teacher_john', 'teacher_john'),
    -- Q111: Security role missing
    ('a_pl900_111_0', 'q_pl900_111', 'The canvas app has not been published', FALSE, 0, 'teacher_john', 'teacher_john'),
    ('a_pl900_111_1', 'q_pl900_111', 'The user does not have the required Dataverse security role to access the table', TRUE, 1, 'teacher_john', 'teacher_john'),
    ('a_pl900_111_2', 'q_pl900_111', 'The Dataverse table has no primary key', FALSE, 2, 'teacher_john', 'teacher_john'),
    ('a_pl900_111_3', 'q_pl900_111', 'The canvas app is not connected to the internet', FALSE, 3, 'teacher_john', 'teacher_john'),
    -- Q112: Filled map
    ('a_pl900_112_0', 'q_pl900_112', 'Line chart', FALSE, 0, 'teacher_john', 'teacher_john'),
    ('a_pl900_112_1', 'q_pl900_112', 'Pie chart', FALSE, 1, 'teacher_john', 'teacher_john'),
    ('a_pl900_112_2', 'q_pl900_112', 'Filled map', TRUE, 2, 'teacher_john', 'teacher_john'),
    ('a_pl900_112_3', 'q_pl900_112', 'Scatter chart', FALSE, 3, 'teacher_john', 'teacher_john'),
    -- Q113: AI Builder
    ('a_pl900_113_0', 'q_pl900_113', 'Power BI', FALSE, 0, 'teacher_john', 'teacher_john'),
    ('a_pl900_113_1', 'q_pl900_113', 'AI Builder', TRUE, 1, 'teacher_john', 'teacher_john'),
    ('a_pl900_113_2', 'q_pl900_113', 'Power Pages', FALSE, 2, 'teacher_john', 'teacher_john'),
    ('a_pl900_113_3', 'q_pl900_113', 'Microsoft Copilot Studio', FALSE, 3, 'teacher_john', 'teacher_john'),
    -- Q114: Navigate function
    ('a_pl900_114_0', 'q_pl900_114', 'Go(Screen2)', FALSE, 0, 'teacher_john', 'teacher_john'),
    ('a_pl900_114_1', 'q_pl900_114', 'Navigate(Screen2)', TRUE, 1, 'teacher_john', 'teacher_john'),
    ('a_pl900_114_2', 'q_pl900_114', 'Load(Screen2)', FALSE, 2, 'teacher_john', 'teacher_john'),
    ('a_pl900_114_3', 'q_pl900_114', 'Back(Screen2)', FALSE, 3, 'teacher_john', 'teacher_john'),
    -- Q115: Scheduled cloud flow
    ('a_pl900_115_0', 'q_pl900_115', 'A manual export from the Power Apps maker portal each weekday', FALSE, 0, 'teacher_john', 'teacher_john'),
    ('a_pl900_115_1', 'q_pl900_115', 'A scheduled Power Automate cloud flow', TRUE, 1, 'teacher_john', 'teacher_john'),
    ('a_pl900_115_2', 'q_pl900_115', 'A Power BI dataset scheduled refresh', FALSE, 2, 'teacher_john', 'teacher_john'),
    ('a_pl900_115_3', 'q_pl900_115', 'A Dataverse business rule', FALSE, 3, 'teacher_john', 'teacher_john'),
    -- Q116: Generative answers
    ('a_pl900_116_0', 'q_pl900_116', 'Entities', FALSE, 0, 'teacher_john', 'teacher_john'),
    ('a_pl900_116_1', 'q_pl900_116', 'Generative answers', TRUE, 1, 'teacher_john', 'teacher_john'),
    ('a_pl900_116_2', 'q_pl900_116', 'Test pane', FALSE, 2, 'teacher_john', 'teacher_john'),
    ('a_pl900_116_3', 'q_pl900_116', 'Power Automate integration', FALSE, 3, 'teacher_john', 'teacher_john'),
    -- Q117: DLP policy
    ('a_pl900_117_0', 'q_pl900_117', 'A Dataverse security role', FALSE, 0, 'teacher_john', 'teacher_john'),
    ('a_pl900_117_1', 'q_pl900_117', 'A Data Loss Prevention (DLP) policy', TRUE, 1, 'teacher_john', 'teacher_john'),
    ('a_pl900_117_2', 'q_pl900_117', 'A managed environment', FALSE, 2, 'teacher_john', 'teacher_john'),
    ('a_pl900_117_3', 'q_pl900_117', 'A Conditional Access policy', FALSE, 3, 'teacher_john', 'teacher_john'),
    -- Q118: Calculated column
    ('a_pl900_118_0', 'q_pl900_118', 'Rollup column', FALSE, 0, 'teacher_john', 'teacher_john'),
    ('a_pl900_118_1', 'q_pl900_118', 'Lookup column', FALSE, 1, 'teacher_john', 'teacher_john'),
    ('a_pl900_118_2', 'q_pl900_118', 'Calculated column', TRUE, 2, 'teacher_john', 'teacher_john'),
    ('a_pl900_118_3', 'q_pl900_118', 'Choice column', FALSE, 3, 'teacher_john', 'teacher_john'),
    -- Q119: Identity provider
    ('a_pl900_119_0', 'q_pl900_119', 'A Dataverse security role', FALSE, 0, 'teacher_john', 'teacher_john'),
    ('a_pl900_119_1', 'q_pl900_119', 'An identity provider with Microsoft as the provider', TRUE, 1, 'teacher_john', 'teacher_john'),
    ('a_pl900_119_2', 'q_pl900_119', 'A canvas app authentication rule', FALSE, 2, 'teacher_john', 'teacher_john'),
    ('a_pl900_119_3', 'q_pl900_119', 'A DLP policy', FALSE, 3, 'teacher_john', 'teacher_john'),
    -- Q120: Solution checker
    ('a_pl900_120_0', 'q_pl900_120', 'Environment diff tool', FALSE, 0, 'teacher_john', 'teacher_john'),
    ('a_pl900_120_1', 'q_pl900_120', 'Solution checker', TRUE, 1, 'teacher_john', 'teacher_john'),
    ('a_pl900_120_2', 'q_pl900_120', 'Managed properties validator', FALSE, 2, 'teacher_john', 'teacher_john'),
    ('a_pl900_120_3', 'q_pl900_120', 'Dependency checker', FALSE, 3, 'teacher_john', 'teacher_john'),
    -- Q121: Canvas vs model-driven
    ('a_pl900_121_0', 'q_pl900_121', 'Canvas apps can only connect to Dataverse; model-driven apps can connect to any data source', FALSE, 0, 'teacher_john', 'teacher_john'),
    ('a_pl900_121_1', 'q_pl900_121', 'Canvas apps give full control over the UI layout; model-driven apps generate the UI automatically based on the data model', TRUE, 1, 'teacher_john', 'teacher_john'),
    ('a_pl900_121_2', 'q_pl900_121', 'Canvas apps require professional coding experience; model-driven apps are no-code', FALSE, 2, 'teacher_john', 'teacher_john'),
    ('a_pl900_121_3', 'q_pl900_121', 'Canvas apps only run on mobile devices; model-driven apps only run on desktop', FALSE, 3, 'teacher_john', 'teacher_john'),
    -- Q122: Form component in model-driven app
    ('a_pl900_122_0', 'q_pl900_122', 'View', FALSE, 0, 'teacher_john', 'teacher_john'),
    ('a_pl900_122_1', 'q_pl900_122', 'Chart', FALSE, 1, 'teacher_john', 'teacher_john'),
    ('a_pl900_122_2', 'q_pl900_122', 'Form', TRUE, 2, 'teacher_john', 'teacher_john'),
    ('a_pl900_122_3', 'q_pl900_122', 'Dashboard', FALSE, 3, 'teacher_john', 'teacher_john'),
    -- Q123: Gallery control
    ('a_pl900_123_0', 'q_pl900_123', 'Form', FALSE, 0, 'teacher_john', 'teacher_john'),
    ('a_pl900_123_1', 'q_pl900_123', 'Label', FALSE, 1, 'teacher_john', 'teacher_john'),
    ('a_pl900_123_2', 'q_pl900_123', 'Gallery', TRUE, 2, 'teacher_john', 'teacher_john'),
    ('a_pl900_123_3', 'q_pl900_123', 'Button', FALSE, 3, 'teacher_john', 'teacher_john'),
    -- Q124: Plug-in
    ('a_pl900_124_0', 'q_pl900_124', 'Business rule', FALSE, 0, 'teacher_john', 'teacher_john'),
    ('a_pl900_124_1', 'q_pl900_124', 'Power Automate cloud flow', FALSE, 1, 'teacher_john', 'teacher_john'),
    ('a_pl900_124_2', 'q_pl900_124', 'Plug-in', TRUE, 2, 'teacher_john', 'teacher_john'),
    ('a_pl900_124_3', 'q_pl900_124', 'Calculated column', FALSE, 3, 'teacher_john', 'teacher_john'),
    -- Q125: SharePoint modified trigger
    ('a_pl900_125_0', 'q_pl900_125', 'When a new file is created in SharePoint', FALSE, 0, 'teacher_john', 'teacher_john'),
    ('a_pl900_125_1', 'q_pl900_125', 'When an item is created or modified in SharePoint', TRUE, 1, 'teacher_john', 'teacher_john'),
    ('a_pl900_125_2', 'q_pl900_125', 'When a new email arrives in Outlook', FALSE, 2, 'teacher_john', 'teacher_john'),
    ('a_pl900_125_3', 'q_pl900_125', 'When a new record is created in Dataverse', FALSE, 3, 'teacher_john', 'teacher_john'),
    -- Q126: Power BI App purpose
    ('a_pl900_126_0', 'q_pl900_126', 'To create new data models in Power BI', FALSE, 0, 'teacher_john', 'teacher_john'),
    ('a_pl900_126_1', 'q_pl900_126', 'To provide a bundled collection of dashboards and reports for distribution to users in an organization', TRUE, 1, 'teacher_john', 'teacher_john'),
    ('a_pl900_126_2', 'q_pl900_126', 'To connect to on-premises data sources', FALSE, 2, 'teacher_john', 'teacher_john'),
    ('a_pl900_126_3', 'q_pl900_126', 'To embed reports in external websites', FALSE, 3, 'teacher_john', 'teacher_john'),
    -- Q127: Model-driven app for customer service
    ('a_pl900_127_0', 'q_pl900_127', 'A Power BI report', FALSE, 0, 'teacher_john', 'teacher_john'),
    ('a_pl900_127_1', 'q_pl900_127', 'A model-driven app built on Dataverse', TRUE, 1, 'teacher_john', 'teacher_john'),
    ('a_pl900_127_2', 'q_pl900_127', 'A canvas app connecting to SharePoint', FALSE, 2, 'teacher_john', 'teacher_john'),
    ('a_pl900_127_3', 'q_pl900_127', 'A Power Pages site', FALSE, 3, 'teacher_john', 'teacher_john'),
    -- Q128: Managed solution
    ('a_pl900_128_0', 'q_pl900_128', 'A solution that can be freely modified in the target environment', FALSE, 0, 'teacher_john', 'teacher_john'),
    ('a_pl900_128_1', 'q_pl900_128', 'A solution that is locked for editing once imported, ensuring version control and preventing unintended changes', TRUE, 1, 'teacher_john', 'teacher_john'),
    ('a_pl900_128_2', 'q_pl900_128', 'A solution that only contains Power Automate flows', FALSE, 2, 'teacher_john', 'teacher_john'),
    ('a_pl900_128_3', 'q_pl900_128', 'A solution that requires premium licensing to import', FALSE, 3, 'teacher_john', 'teacher_john'),
    -- Q129: AI Builder + Power Automate for invoices (multiple)
    ('a_pl900_129_0', 'q_pl900_129', 'AI Builder document processing', TRUE, 0, 'teacher_john', 'teacher_john'),
    ('a_pl900_129_1', 'q_pl900_129', 'Power Pages', FALSE, 1, 'teacher_john', 'teacher_john'),
    ('a_pl900_129_2', 'q_pl900_129', 'Power Automate cloud flow', TRUE, 2, 'teacher_john', 'teacher_john'),
    ('a_pl900_129_3', 'q_pl900_129', 'Power BI', FALSE, 3, 'teacher_john', 'teacher_john'),
    ('a_pl900_129_4', 'q_pl900_129', 'Microsoft Copilot Studio', FALSE, 4, 'teacher_john', 'teacher_john'),
    -- Q130: Pin visuals to dashboard
    ('a_pl900_130_0', 'q_pl900_130', 'Create a new report that imports all other reports', FALSE, 0, 'teacher_john', 'teacher_john'),
    ('a_pl900_130_1', 'q_pl900_130', 'Pin visuals from each report to a dashboard', TRUE, 1, 'teacher_john', 'teacher_john'),
    ('a_pl900_130_2', 'q_pl900_130', 'Export all reports to PDF and combine them', FALSE, 2, 'teacher_john', 'teacher_john'),
    ('a_pl900_130_3', 'q_pl900_130', 'Create a new workspace for each report', FALSE, 3, 'teacher_john', 'teacher_john'),
    -- Q131: Model-driven app view purpose
    ('a_pl900_131_0', 'q_pl900_131', 'To define the layout of fields when opening a record', FALSE, 0, 'teacher_john', 'teacher_john'),
    ('a_pl900_131_1', 'q_pl900_131', 'To display a filtered and sorted list of records from a Dataverse table', TRUE, 1, 'teacher_john', 'teacher_john'),
    ('a_pl900_131_2', 'q_pl900_131', 'To automate a business process across stages', FALSE, 2, 'teacher_john', 'teacher_john'),
    ('a_pl900_131_3', 'q_pl900_131', 'To add visualizations to an app dashboard', FALSE, 3, 'teacher_john', 'teacher_john'),
    -- Q132: Custom connector
    ('a_pl900_132_0', 'q_pl900_132', 'A premium connector', FALSE, 0, 'teacher_john', 'teacher_john'),
    ('a_pl900_132_1', 'q_pl900_132', 'A custom connector', TRUE, 1, 'teacher_john', 'teacher_john'),
    ('a_pl900_132_2', 'q_pl900_132', 'An on-premises data gateway', FALSE, 2, 'teacher_john', 'teacher_john'),
    ('a_pl900_132_3', 'q_pl900_132', 'A virtual table', FALSE, 3, 'teacher_john', 'teacher_john'),
    -- Q133: Connect to data source first
    ('a_pl900_133_0', 'q_pl900_133', 'Create visualizations', FALSE, 0, 'teacher_john', 'teacher_john'),
    ('a_pl900_133_1', 'q_pl900_133', 'Publish the report to the Power BI service', FALSE, 1, 'teacher_john', 'teacher_john'),
    ('a_pl900_133_2', 'q_pl900_133', 'Connect to the data source', TRUE, 2, 'teacher_john', 'teacher_john'),
    ('a_pl900_133_3', 'q_pl900_133', 'Configure row-level security', FALSE, 3, 'teacher_john', 'teacher_john'),
    -- Q134: Scheduled trigger
    ('a_pl900_134_0', 'q_pl900_134', 'Automated trigger', FALSE, 0, 'teacher_john', 'teacher_john'),
    ('a_pl900_134_1', 'q_pl900_134', 'Instant trigger', FALSE, 1, 'teacher_john', 'teacher_john'),
    ('a_pl900_134_2', 'q_pl900_134', 'Scheduled trigger', TRUE, 2, 'teacher_john', 'teacher_john'),
    ('a_pl900_134_3', 'q_pl900_134', 'Manual trigger', FALSE, 3, 'teacher_john', 'teacher_john'),
    -- Q135: Add Teams channel in Copilot Studio
    ('a_pl900_135_0', 'q_pl900_135', 'Create a new copilot specifically for Teams', FALSE, 0, 'teacher_john', 'teacher_john'),
    ('a_pl900_135_1', 'q_pl900_135', 'Add the Microsoft Teams channel in the Publish section of Copilot Studio', TRUE, 1, 'teacher_john', 'teacher_john'),
    ('a_pl900_135_2', 'q_pl900_135', 'Export the copilot and import it into Teams', FALSE, 2, 'teacher_john', 'teacher_john'),
    ('a_pl900_135_3', 'q_pl900_135', 'Configure a DLP policy to allow Teams access', FALSE, 3, 'teacher_john', 'teacher_john'),
    -- Q136: Security role record-level privileges
    ('a_pl900_136_0', 'q_pl900_136', 'Field security profiles', FALSE, 0, 'teacher_john', 'teacher_john'),
    ('a_pl900_136_1', 'q_pl900_136', 'Security roles with record-level privileges', TRUE, 1, 'teacher_john', 'teacher_john'),
    ('a_pl900_136_2', 'q_pl900_136', 'Business rules', FALSE, 2, 'teacher_john', 'teacher_john'),
    ('a_pl900_136_3', 'q_pl900_136', 'Managed properties', FALSE, 3, 'teacher_john', 'teacher_john'),
    -- Q137: Automated cloud flow for Dataverse
    ('a_pl900_137_0', 'q_pl900_137', 'Scheduled flow', FALSE, 0, 'teacher_john', 'teacher_john'),
    ('a_pl900_137_1', 'q_pl900_137', 'Instant flow', FALSE, 1, 'teacher_john', 'teacher_john'),
    ('a_pl900_137_2', 'q_pl900_137', 'Automated cloud flow', TRUE, 2, 'teacher_john', 'teacher_john'),
    ('a_pl900_137_3', 'q_pl900_137', 'Desktop flow', FALSE, 3, 'teacher_john', 'teacher_john'),
    -- Q138: External identity providers in Power Pages
    ('a_pl900_138_0', 'q_pl900_138', 'Azure Active Directory only', FALSE, 0, 'teacher_john', 'teacher_john'),
    ('a_pl900_138_1', 'q_pl900_138', 'External identity providers (OAuth 2.0 / OpenID Connect)', TRUE, 1, 'teacher_john', 'teacher_john'),
    ('a_pl900_138_2', 'q_pl900_138', 'Dataverse security roles', FALSE, 2, 'teacher_john', 'teacher_john'),
    ('a_pl900_138_3', 'q_pl900_138', 'DLP policies', FALSE, 3, 'teacher_john', 'teacher_john'),
    -- Q139: Dataverse Web API
    ('a_pl900_139_0', 'q_pl900_139', 'To create canvas apps visually', FALSE, 0, 'teacher_john', 'teacher_john'),
    ('a_pl900_139_1', 'q_pl900_139', 'To provide a RESTful API for accessing and manipulating Dataverse data from external applications', TRUE, 1, 'teacher_john', 'teacher_john'),
    ('a_pl900_139_2', 'q_pl900_139', 'To design Power BI reports', FALSE, 2, 'teacher_john', 'teacher_john'),
    ('a_pl900_139_3', 'q_pl900_139', 'To run Power Automate desktop flows', FALSE, 3, 'teacher_john', 'teacher_john'),
    -- Q140: Components that use Dataverse (multiple) - Power Apps + Power Pages
    ('a_pl900_140_0', 'q_pl900_140', 'Power Apps', TRUE, 0, 'teacher_john', 'teacher_john'),
    ('a_pl900_140_1', 'q_pl900_140', 'Power BI Desktop (standalone)', FALSE, 1, 'teacher_john', 'teacher_john'),
    ('a_pl900_140_2', 'q_pl900_140', 'Power Pages', TRUE, 2, 'teacher_john', 'teacher_john'),
    ('a_pl900_140_3', 'q_pl900_140', 'Azure DevOps', FALSE, 3, 'teacher_john', 'teacher_john'),
    ('a_pl900_140_4', 'q_pl900_140', 'Microsoft Excel (standalone)', FALSE, 4, 'teacher_john', 'teacher_john'),
    -- Q141: Default environment
    ('a_pl900_141_0', 'q_pl900_141', 'Developer', FALSE, 0, 'teacher_john', 'teacher_john'),
    ('a_pl900_141_1', 'q_pl900_141', 'Trial', FALSE, 1, 'teacher_john', 'teacher_john'),
    ('a_pl900_141_2', 'q_pl900_141', 'Default', TRUE, 2, 'teacher_john', 'teacher_john'),
    ('a_pl900_141_3', 'q_pl900_141', 'Sandbox', FALSE, 3, 'teacher_john', 'teacher_john'),
    -- Q142: Train and publish AI Builder model
    ('a_pl900_142_0', 'q_pl900_142', 'Deploy the model to Azure Machine Learning', FALSE, 0, 'teacher_john', 'teacher_john'),
    ('a_pl900_142_1', 'q_pl900_142', 'Train and publish the model', TRUE, 1, 'teacher_john', 'teacher_john'),
    ('a_pl900_142_2', 'q_pl900_142', 'Export the model to Power BI', FALSE, 2, 'teacher_john', 'teacher_john'),
    ('a_pl900_142_3', 'q_pl900_142', 'Register the model in Dataverse', FALSE, 3, 'teacher_john', 'teacher_john'),
    -- Q143: Power Apps maker portal
    ('a_pl900_143_0', 'q_pl900_143', 'Azure DevOps', FALSE, 0, 'teacher_john', 'teacher_john'),
    ('a_pl900_143_1', 'q_pl900_143', 'Visual Studio Code', FALSE, 1, 'teacher_john', 'teacher_john'),
    ('a_pl900_143_2', 'q_pl900_143', 'The Power Apps maker portal', TRUE, 2, 'teacher_john', 'teacher_john'),
    ('a_pl900_143_3', 'q_pl900_143', 'SQL Server Management Studio', FALSE, 3, 'teacher_john', 'teacher_john'),
    -- Q144: Retry policy
    ('a_pl900_144_0', 'q_pl900_144', 'Run after settings', FALSE, 0, 'teacher_john', 'teacher_john'),
    ('a_pl900_144_1', 'q_pl900_144', 'Concurrency control', FALSE, 1, 'teacher_john', 'teacher_john'),
    ('a_pl900_144_2', 'q_pl900_144', 'Retry policy', TRUE, 2, 'teacher_john', 'teacher_john'),
    ('a_pl900_144_3', 'q_pl900_144', 'Timeout settings', FALSE, 3, 'teacher_john', 'teacher_john'),
    -- Q145: Sandbox for developer testing
    ('a_pl900_145_0', 'q_pl900_145', 'Default', FALSE, 0, 'teacher_john', 'teacher_john'),
    ('a_pl900_145_1', 'q_pl900_145', 'Trial', FALSE, 1, 'teacher_john', 'teacher_john'),
    ('a_pl900_145_2', 'q_pl900_145', 'Sandbox', TRUE, 2, 'teacher_john', 'teacher_john'),
    ('a_pl900_145_3', 'q_pl900_145', 'Production', FALSE, 3, 'teacher_john', 'teacher_john'),
    -- Q146: Text() function for currency formatting
    ('a_pl900_146_0', 'q_pl900_146', 'Value(number, "$#,##0.00")', FALSE, 0, 'teacher_john', 'teacher_john'),
    ('a_pl900_146_1', 'q_pl900_146', 'Text(number, "$#,##0.00")', TRUE, 1, 'teacher_john', 'teacher_john'),
    ('a_pl900_146_2', 'q_pl900_146', 'Format(number, "currency")', FALSE, 2, 'teacher_john', 'teacher_john'),
    ('a_pl900_146_3', 'q_pl900_146', 'PlainText(number, "$#,##0.00")', FALSE, 3, 'teacher_john', 'teacher_john'),
    -- Q147: Table permissions in Power Pages
    ('a_pl900_147_0', 'q_pl900_147', 'Dataverse field security profiles', FALSE, 0, 'teacher_john', 'teacher_john'),
    ('a_pl900_147_1', 'q_pl900_147', 'Power Pages table permissions', TRUE, 1, 'teacher_john', 'teacher_john'),
    ('a_pl900_147_2', 'q_pl900_147', 'Power Automate approval flows', FALSE, 2, 'teacher_john', 'teacher_john'),
    ('a_pl900_147_3', 'q_pl900_147', 'DLP policies', FALSE, 3, 'teacher_john', 'teacher_john'),
    -- Q148: Multi-selection controls - Combo box + List box (multiple)
    ('a_pl900_148_0', 'q_pl900_148', 'Radio', FALSE, 0, 'teacher_john', 'teacher_john'),
    ('a_pl900_148_1', 'q_pl900_148', 'Combo box', TRUE, 1, 'teacher_john', 'teacher_john'),
    ('a_pl900_148_2', 'q_pl900_148', 'Toggle', FALSE, 2, 'teacher_john', 'teacher_john'),
    ('a_pl900_148_3', 'q_pl900_148', 'List box', TRUE, 3, 'teacher_john', 'teacher_john'),
    ('a_pl900_148_4', 'q_pl900_148', 'Rating', FALSE, 4, 'teacher_john', 'teacher_john'),
    -- Q149: Power Platform admin center for monitoring
    ('a_pl900_149_0', 'q_pl900_149', 'Power Apps Studio', FALSE, 0, 'teacher_john', 'teacher_john'),
    ('a_pl900_149_1', 'q_pl900_149', 'Power BI Desktop', FALSE, 1, 'teacher_john', 'teacher_john'),
    ('a_pl900_149_2', 'q_pl900_149', 'The Power Platform admin center', TRUE, 2, 'teacher_john', 'teacher_john'),
    ('a_pl900_149_3', 'q_pl900_149', 'Microsoft Teams admin center', FALSE, 3, 'teacher_john', 'teacher_john'),
    -- Q150: Create a public view for model-driven app access
    ('a_pl900_150_0', 'q_pl900_150', 'Create a new Dataverse table', FALSE, 0, 'teacher_john', 'teacher_john'),
    ('a_pl900_150_1', 'q_pl900_150', 'Create a new canvas app', FALSE, 1, 'teacher_john', 'teacher_john'),
    ('a_pl900_150_2', 'q_pl900_150', 'Create a new personal view', FALSE, 2, 'teacher_john', 'teacher_john'),
    ('a_pl900_150_3', 'q_pl900_150', 'Share the app and assign the appropriate security role to the users', TRUE, 3, 'teacher_john', 'teacher_john')
ON CONFLICT (id) DO NOTHING;
