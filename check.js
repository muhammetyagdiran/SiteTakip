const { createClient } = require('@supabase/supabase-js');

const supabase = createClient(
  'https://vsgvdzeasejwzcdzxnmp.supabase.co',
  'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InZzZ3ZkemVhc2Vqd3pjZHp4bm1wIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzE1ODQ5MDQsImV4cCI6MjA4NzE2MDkwNH0.BkjLOYjk1cixsDwgKuGRR5PK7CVq00BLjvrSUUaWWVg'
);

async function check() {
  const { data, error } = await supabase.from('profiles').select('email, role, full_name, id');
  if (error) console.error(error);
  else console.log(data);
}
check();
