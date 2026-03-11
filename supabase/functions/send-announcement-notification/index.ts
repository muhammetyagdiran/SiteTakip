import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from "https://esm.sh/@supabase/supabase-js@2"
import * as jose from "https://deno.land/x/jose@v4.14.4/index.ts"

// Firebase Service Account Key (User provided)
const serviceAccount = {
    "type": "service_account",
    "project_id": "sitetakip-24351",
    "private_key": "-----BEGIN PRIVATE KEY-----\nMIIEvQIBADANBgkqhkiG9w0BAQEFAASCBKcwggSjAgEAAoIBAQC5LfU5QgviS/q7\nULrse/fnpwBmNHPnTm/OsEcOyKGdoZx+iKyOQksX0p51ChD9B9iL30+NYnFRcxoO\nTW02CH4j8zI7QvhSqCBgjql/CWMMDqx3UYIWui1m7L9NEzP4AH781K81uzGIiMgt\nlYkoyoHbAV/66l6lIuPrlwS8UxW+tn6A5ymJD/gQDU3ciRLx/BfxsnTA4ucNd4r3\n7Tquci5xoC6RUCQT5QmaK+F0qiT8JaCy87D3rVJ66a/NJVO+vl1oKypg9n3DQFWI\nfeBcndGRU22m3NfxLw4yrk2WUfbupW1LAuZoD0PqRTJv77T9y6MbWTisYnuQJ9Dl\nfWYstwsbAgMBAAECggEACr2PfW3cakM1keYUTsFqobfYzj9uQN/BR2UyXI6mz7w/\nFe26cxkwPtD7Wiwmdm6dO5D3uGpvH9DDwEmdsyZvSTQtWSzrYevuI3uSztNODeB6\nAK+sZ8IOU8EZNWYO5mxXm+Aqy2cwmnaIhHBUahZuIrQ5NhX1kwbA3noTZGg97iI8\nATpBkkLjist/2U/XeKYGKf5E3uYjwUCtPnv5mz7/tiBf8APrgAIvUGA+dSZWN0Wg\nA3GcFz2nl4wJI7ZgRT0Bw/yfOh6m18pPVkZYBH7vhMLkQccZwgMKcohjv1JlfKDL\n4+10jL1iKDrGfup4aBku6FVZKpz3Zmzh8uMZ56wEsQKBgQDa2A6m1Y+Y7of5iui1\n2cIIcx5YZVpC6nNifz4FMI1DYTW9u1pBAe0EgRwOK8yiQVnXBIAdKdaJyY0r0rae\nk1evOgkcOUVC4gUTTde4TNF/utuN1596M2h4kUnd/GtzfPdEdhelca6IQQAnuGpO\n5kucQImXj4BjBcOYnwj71IF4iwKBgQDYnrE858E34JVksnLLiMyCdLSU4FIDA7oC\nKYN7oXr7qwpXqpZAjb3VCotiz1EChqJ8A3390cjmLXPFiSnpwqr7YjNN6sXxI0/Q\SyA3P4ojaSKfO+0V1CvSdoOWfdFmzvL3F29s3ClhUVzshV8rH8zewl55UvoX3Pl1\nrZ3tRct5sQKBgDbqzRJ0uSpJgXnPsAIieRyhttW76WCtcPMgtzGaM3jbJh9MqqNx\nlkbxF1c/CoUVHTRl/rhSzXGaUIDUydsVYoWobKzWelkEWv2zJRUswc3p2DrKB00l\nJWxMGVtJgrVigLJ/aAOueXvbw+wzzQmrpQG6+Ew+SJuQ0Lq1/g0kELFtAoGBAI8K\nW2cockJ/nqbb30nfj4wlnIkih4VOFKoQ163vt9Iv46h4ELeX4V6ok9ovpALS/MB/\nXdcZjFvSb7xlErQ1w8oz0kUFXqgY9T9KHH/fCUzQw/f6Dlh3vmg/sizR8FC/H1li\ntEViLEEDBSV5/Jnxacs+9juPO24+kMvQVZS0neRBAoGALX5Mri+vbPY5smLbwzw9\nT+MxNr3UEMBpWuHp/35S2w9dlYsNW0aWJHdeReT62o+bWSVTDjyFIS9CQ6QqiyIJ\neTSTV6X10m6TPlm8AfNt7IchOc/vRQhWe98EvkwlcYElj3l37wttMq1QWFtSVIdx\nvoatnXIQ8sAKv6o4pYO7dDE=\n-----END PRIVATE KEY-----\n",
    "client_email": "firebase-adminsdk-fbsvc@sitetakip-24351.iam.gserviceaccount.com"
};

async function getAccessToken() {
    const iat = Math.floor(Date.now() / 1000);
    const exp = iat + 3600;

    const jwt = await new jose.SignJWT({
        iss: serviceAccount.client_email,
        scope: "https://www.googleapis.com/auth/firebase.messaging",
        aud: "https://oauth2.googleapis.com/token",
        exp,
        iat,
    })
        .setProtectedHeader({ alg: "RS256" })
        .sign(await jose.importPKCS8(serviceAccount.private_key, "RS256"));

    const response = await fetch("https://oauth2.googleapis.com/token", {
        method: "POST",
        headers: {
            "Content-Type": "application/x-www-form-urlencoded",
        },
        body: new URLSearchParams({
            grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer",
            assertion: jwt,
        }),
    });

    const data = await response.json();
    if (data.error) throw new Error(`Google Auth Error: ${data.error_description || data.error}`);
    return data.access_token;
}

serve(async (req) => {
    try {
        const { announcement } = await req.json();
        const siteId = announcement.site_id;
        const title = announcement.title;
        const content = announcement.content;

        // Supabase Client
        const supabase = createClient(
            Deno.env.get('SUPABASE_URL') ?? '',
            Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
        );

        // Fetch FCM tokens of residents in this site
        // We join profiles with apartments and blocks to filter by site_id
        const { data: profiles, error: profileError } = await supabase
            .from('profiles')
            .select('fcm_token, apartments!inner(blocks!inner(site_id))')
            .eq('apartments.blocks.site_id', siteId)
            .not('fcm_token', 'is', null);

        if (profileError) throw profileError;

        const tokens = profiles.map((p: any) => p.fcm_token);
        if (tokens.length === 0) return new Response("No tokens found", { status: 200 });

        const accessToken = await getAccessToken();
        const fcmUrl = `https://fcm.googleapis.com/v1/projects/${serviceAccount.project_id}/messages:send`;

        // Send notifications
        const results = await Promise.all(tokens.map((token: string) =>
            fetch(fcmUrl, {
                method: 'POST',
                headers: {
                    'Authorization': `Bearer ${accessToken}`,
                    'Content-Type': 'application/json',
                },
                body: JSON.stringify({
                    message: {
                        token: token,
                        notification: {
                            title: `Yeni Duyuru: ${title}`,
                            body: content
                        },
                        data: {
                            siteId: siteId,
                            type: 'announcement'
                        }
                    }
                })
            }).then(res => res.json())
        ));

        return new Response(JSON.stringify({ success: true, results }), {
            headers: { "Content-Type": "application/json" },
        });

    } catch (error) {
        return new Response(JSON.stringify({ error: error.message }), { status: 500 });
    }
})
