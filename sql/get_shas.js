// UDF definition
function get_shas(row, emit) {
  try {
    var shared = {
      id: row.id,
      payload: row.payload,
      shas: null,
      error: null
    };
    var commits = JSON.parse(row.payload).commits;
    if (commits == null) {
      shared.error = 'Not a PushEvent';
      emit(shared);
      return;
    }
    shared.shas = commits.map(commit=>commit.sha).join(',')
    emit(shared);
  } catch(error) {
    shared.error = error.message;
    emit(shared);
  }
}

// UDF registration
bigquery.defineFunction(
  'get_shas',   // Name used to call the function from SQL
  [
    'id', // In
    'payload'
  ],
  [
    {name: 'id',      type: 'string'}, // Out
    {name: 'payload', type: 'string'},
    {name: 'shas',    type: 'string'},
    {name: 'error',   type: 'string'},
  ],
  get_shas
);
