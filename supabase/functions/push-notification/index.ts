import { createClient } from 'npm:@supabase/supabase-js@2'
import { JWT } from 'npm:google-auth-library'

// 1. Configuración e Inicialización
const supabaseUrl = Deno.env.get('SUPABASE_URL')!
const supabaseServiceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
const supabase = createClient(supabaseUrl, supabaseServiceKey)

interface WebhookPayload {
  type: 'INSERT' | 'UPDATE' | 'DELETE'
  table: string
  record: any
  old_record: any
}

// 2. Servicios Externos (FCM)
async function getAccessToken(): Promise<string> {
  const serviceAccountStr = Deno.env.get('FIREBASE_SERVICE_ACCOUNT')
  if (!serviceAccountStr) throw new Error('Missing FIREBASE_SERVICE_ACCOUNT env var')
  const serviceAccount = JSON.parse(serviceAccountStr)
  const jwtClient = new JWT({
    email: serviceAccount.client_email,
    key: serviceAccount.private_key,
    scopes: ['https://www.googleapis.com/auth/firebase.messaging'],
  })
  const tokens = await jwtClient.authorize()
  return tokens.access_token!
}

async function sendPushNotification(fcmToken: string, title: string, body: string, dataPayload: Record<string, string> = {}) {
  if (!fcmToken) return;
  const serviceAccountStr = Deno.env.get('FIREBASE_SERVICE_ACCOUNT')
  const projectId = JSON.parse(serviceAccountStr!).project_id
  const accessToken = await getAccessToken()

  const res = await fetch(`https://fcm.googleapis.com/v1/projects/${projectId}/messages:send`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${accessToken}` },
    body: JSON.stringify({
      message: {
        token: fcmToken,
        notification: { title, body },
        data: dataPayload,
        android: { priority: "high", notification: { sound: "default", channel_id: "high_importance_channel" } },
        apns: { payload: { aps: { sound: "default" } } },
      },
    }),
  })

  if (!res.ok) {
    console.error('Error enviando a FCM:', await res.json())
  }
}

// 3. Repositorio / Consultas a la BD
async function getBusinessOwnerTokens(businessId: string) {
  const { data: business } = await supabase.from('businesses').select('owner_id, name').eq('id', businessId).single()
  if (!business) return { businessName: 'un negocio', ownerTokens: [] }
  const { data: owner } = await supabase.from('profiles').select('fcm_token').eq('id', business.owner_id).single()
  return { businessName: business.name, ownerToken: owner?.fcm_token }
}

async function getUserTokenAndName(userId: string) {
  const { data: user } = await supabase.from('profiles').select('full_name, fcm_token').eq('id', userId).single()
  return { userName: user?.full_name || 'Un usuario', userToken: user?.fcm_token }
}

async function getAdminTokens() {
  const { data: admins } = await supabase.from('profiles').select('fcm_token').eq('role', 'admin')
  return (admins || []).map(a => a.fcm_token).filter(Boolean)
}

async function broadcastToAdmins(title: string, body: string, route: string) {
  const tokens = await getAdminTokens();
  for (const token of tokens) {
    await sendPushNotification(token, title, body, { route });
  }
}

// 4. Manejadores de Dominio
async function handleProfiles(payload: WebhookPayload) {
  if (payload.type === 'INSERT') {
    const profile = payload.record;
    
    // Esperar 1 segundo para que la app (Dart) tenga tiempo de hacer el upsert
    await new Promise(resolve => setTimeout(resolve, 1000));
    
    // Consultar el perfil actualizado
    const { data: updatedProfile } = await supabase.from('profiles').select('full_name, role').eq('id', profile.id).single();
    
    let name = updatedProfile?.full_name || profile.full_name;
    let actualRole = updatedProfile?.role || profile.role;
    
    // Fallback final a metadata
    if (!name) {
      try {
        const { data: userData } = await supabase.auth.admin.getUserById(profile.id);
        name = userData?.user?.user_metadata?.full_name || userData?.user?.user_metadata?.name;
        actualRole = actualRole === 'client' ? (userData?.user?.user_metadata?.role || actualRole) : actualRole;
      } catch (e) {
        console.error('Error fetching user meta:', e);
      }
    }
    
    name = name || 'Un nuevo usuario';
    
    if (actualRole === 'client') {
      await broadcastToAdmins('Nuevo Cliente', `${name} creó cuenta como cliente.`, '/admin_users');
    } else if (actualRole === 'business' || actualRole === 'owner') {
      await broadcastToAdmins('Nueva Cuenta de Dueño', `${name} acaba de crear cuenta con rol dueño.`, '/admin_users');
    }
  }
}

async function handleBusinesses(payload: WebhookPayload) {
  if (payload.type === 'INSERT') {
    const business = payload.record;
    const { userName } = await getUserTokenAndName(business.owner_id);
    await broadcastToAdmins('Nuevo Negocio Registrado', `Se creó una nueva cuenta como negocio (${business.name} por ${userName}). Apruebe o póngase en contacto.`, '/admin_businesses');
  }
}

async function handleScans(payload: WebhookPayload) {
  const scan = payload.record;
  const { businessName, ownerToken } = await getBusinessOwnerTokens(scan.business_id);
  const { userName: clientName, userToken: clientToken } = await getUserTokenAndName(scan.user_id);

  if (payload.type === 'INSERT' && scan.status === 'pending') {
    if (ownerToken) {
      await sendPushNotification(ownerToken, '¡Nuevo escaneo!', `${clientName} hizo un escaneo, pendiente de aprobar.`, { route: '/business_dashboard' });
    }
    await broadcastToAdmins('Nuevo Escaneo 📸', `${clientName} escaneó un QR en ${businessName}.`, '/admin_activity');
  }

  // Si se aprueba manualmente sin QR
  if (payload.type === 'INSERT' && scan.status === 'approved' && !scan.qr_code_id) {
    if (clientToken) {
      await sendPushNotification(clientToken, '¡Punto asignado manualmente! 🎉', `${businessName} te ha dado un punto.`, { route: '/my_cards' });
    }
    await broadcastToAdmins('Punto Manual ⚡', `${businessName} asignó un punto manualmente a ${clientName}.`, '/admin_activity');
  }

  if (payload.type === 'UPDATE' && scan.status === 'approved' && payload.old_record?.status !== 'approved') {
    if (clientToken) {
      await sendPushNotification(clientToken, '¡Punto aprobado! 🎉', `Tu escaneo en ${businessName} fue aprobado.`, { route: '/my_cards' });
    }
    await broadcastToAdmins('Escaneo Aprobado ✅', `${businessName} aprobó el escaneo de ${clientName}.`, '/admin_activity');
  }

  if (payload.type === 'UPDATE' && scan.status === 'rejected' && payload.old_record?.status !== 'rejected') {
    if (clientToken) {
      await sendPushNotification(clientToken, 'Escaneo rechazado ❌', `Tu escaneo en ${businessName} no fue aprobado.`, { route: '/my_cards' });
    }
    await broadcastToAdmins('Escaneo Rechazado ❌', `${businessName} rechazó el escaneo de ${clientName}.`, '/admin_activity');
  }
}

async function handleRewards(payload: WebhookPayload) {
  const reward = payload.record;
  const { businessName, ownerToken } = await getBusinessOwnerTokens(reward.business_id);
  const { userName: clientName, userToken: clientToken } = await getUserTokenAndName(reward.user_id);

  if (payload.type === 'INSERT') {
    if (ownerToken) {
      await sendPushNotification(ownerToken, '¡Premio solicitado! 🎁', `${clientName} ganó un premio, pendiente de aprobar.`, { route: '/business_dashboard/rewards' });
    }
    if (clientToken) {
      await sendPushNotification(clientToken, '¡Premio alcanzado! 🎁', `Haz ganado premio en ${businessName}, acercate a retirar, la aprobación esta pendiente.`, { route: '/my_cards' });
    }
    await broadcastToAdmins('Premio Alcanzado 🎁', `${clientName} alcanzó un premio en ${businessName}.`, '/admin_rewards');
  }

  if (payload.type === 'UPDATE' && (reward.status === 'approved' || reward.status === 'claimed') && payload.old_record?.status !== reward.status) {
    if (clientToken) {
      await sendPushNotification(clientToken, '¡Premio entregado! 🥳', `Tu premio en ${businessName} fue aprobado.`, { route: '/my_cards' });
    }
    await broadcastToAdmins('Premio Entregado ✅', `${businessName} entregó el premio a ${clientName}.`, '/admin_rewards');
  }

  if (payload.type === 'UPDATE' && reward.status === 'rejected' && payload.old_record?.status !== 'rejected') {
    if (clientToken) {
      await sendPushNotification(clientToken, 'Premio rechazado ❌', `Tu premio en ${businessName} fue rechazado.`, { route: '/my_cards' });
    }
    await broadcastToAdmins('Premio Rechazado ❌', `${businessName} rechazó el premio de ${clientName}.`, '/admin_rewards');
  }
}

async function handleRewardTransfers(payload: WebhookPayload) {
  if (payload.type === 'INSERT') {
    const transfer = payload.record;
    const { businessName, ownerToken } = await getBusinessOwnerTokens(transfer.business_id);
    const { userName: senderName } = await getUserTokenAndName(transfer.from_user_id);
    const { userName: receiverName, userToken: receiverToken } = await getUserTokenAndName(transfer.to_user_id);

    if (receiverToken) {
      await sendPushNotification(receiverToken, '¡Te han transferido un premio! 🎁', `${senderName} te regaló un premio de ${businessName}. Entra para ver cómo retirarlo.`, { route: '/my_cards' });
    }

    if (ownerToken) {
      await sendPushNotification(ownerToken, 'Transferencia de premio 🔄', `${senderName} transfirió su premio a ${receiverName}.`, { route: '/business_dashboard' });
    }

    await broadcastToAdmins('Premio Transferido 🔄', `${senderName} transfirió un premio a ${receiverName} en ${businessName}.`, '/admin_rewards');
  }
}

// 5. Controlador Principal
Deno.serve(async (req) => {
  try {
    const payload: WebhookPayload = await req.json();

    switch (payload.table) {
      case 'profiles':
        await handleProfiles(payload);
        break;
      case 'businesses':
        await handleBusinesses(payload);
        break;
      case 'scans':
        await handleScans(payload);
        break;
      case 'rewards':
        await handleRewards(payload);
        break;
      case 'reward_transfer_history':
        await handleRewardTransfers(payload);
        break;
    }

    return new Response(JSON.stringify({ success: true }), { headers: { 'Content-Type': 'application/json' } })
  } catch (error: any) {
    console.error('Webhook error:', error)
    return new Response(JSON.stringify({ error: error.message }), { status: 500 })
  }
})
