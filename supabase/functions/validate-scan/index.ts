import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';
const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type'
};
serve(async (req)=>{
  // Handle CORS preflight
  if (req.method === 'OPTIONS') {
    return new Response('ok', {
      headers: corsHeaders
    });
  }
  try {
    // Obtener datos del request
    const { qr_code, user_id } = await req.json();
    if (!qr_code || !user_id) {
      return new Response(JSON.stringify({
        success: false,
        error: 'Faltan parámetros: qr_code y user_id son requeridos'
      }), {
        headers: {
          ...corsHeaders,
          'Content-Type': 'application/json'
        },
        status: 400
      });
    }
    // Crear cliente de Supabase con service_role_key (permisos totales)
    const supabaseClient = createClient(Deno.env.get('SUPABASE_URL') ?? '', Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '');
    // ==========================================
    // PASO 1: Verificar que el QR existe y está activo
    // ==========================================
    const { data: qrData, error: qrError } = await supabaseClient.from('qr_codes').select(`
        id,
        business_id,
        is_active,
        businesses!inner (
          id,
          name,
          category,
          reward_description,
          points_required,
          cooldown_hours,
          is_active
        )
      `).eq('qr_code', qr_code).eq('is_active', true).single();
    if (qrError || !qrData || !qrData.businesses.is_active) {
      // Registrar intento fallido
      await supabaseClient.from('scan_attempts').insert({
        user_id,
        business_id: qrData?.business_id || null,
        qr_code_id: qrData?.id || null,
        success: false,
        failure_reason: 'invalid_qr_or_inactive_business'
      });
      return new Response(JSON.stringify({
        success: false,
        error: 'QR inválido o negocio inactivo'
      }), {
        headers: {
          ...corsHeaders,
          'Content-Type': 'application/json'
        },
        status: 404
      });
    }
    const business = qrData.businesses;
    const qr_code_id = qrData.id;
    // ==========================================
    // PASO 2: Verificar COOLDOWN
    // ==========================================
    const { data: loyaltyCard, error: cardError } = await supabaseClient.from('loyalty_cards').select('id, current_points, total_points_lifetime, rewards_claimed, last_scan_at').eq('user_id', user_id).eq('business_id', business.id).maybeSingle();
    // Si existe la tarjeta, verificar cooldown
    if (loyaltyCard && loyaltyCard.last_scan_at) {
      const lastScanTime = new Date(loyaltyCard.last_scan_at).getTime();
      const currentTime = Date.now();
      const cooldownMs = business.cooldown_hours * 60 * 60 * 1000;
      const timeSinceLastScan = currentTime - lastScanTime;
      if (timeSinceLastScan < cooldownMs) {
        // AÚN ESTÁ EN COOLDOWN
        const remainingMs = cooldownMs - timeSinceLastScan;
        const remainingMinutes = Math.ceil(remainingMs / 60000);
        const remainingHours = Math.floor(remainingMinutes / 60);
        const remainingMins = remainingMinutes % 60;
        // Registrar intento fallido
        await supabaseClient.from('scan_attempts').insert({
          user_id,
          business_id: business.id,
          qr_code_id,
          success: false,
          failure_reason: 'cooldown_active'
        });
        return new Response(JSON.stringify({
          success: false,
          error: 'cooldown',
          message: `Ya escaneaste en ${business.name}. Vuelve en ${remainingHours}h ${remainingMins}min`,
          remaining_minutes: remainingMinutes,
          remaining_hours: remainingHours,
          business_name: business.name
        }), {
          headers: {
            ...corsHeaders,
            'Content-Type': 'application/json'
          },
          status: 429
        });
      }
    }
    // ==========================================
    // PASO 3: COOLDOWN PASADO - Proceder con el escaneo
    // ==========================================
    let cardId = loyaltyCard?.id;
    let currentPoints = loyaltyCard?.current_points || 0;
    let totalPointsLifetime = loyaltyCard?.total_points_lifetime || 0;
    let rewardsClaimed = loyaltyCard?.rewards_claimed || 0;
    // Si no existe la tarjeta, crearla
    if (!loyaltyCard) {
      const { data: newCard, error: newCardError } = await supabaseClient.from('loyalty_cards').insert({
        user_id,
        business_id: business.id,
        current_points: 0,
        total_points_lifetime: 0,
        rewards_claimed: 0,
        last_scan_at: null
      }).select().single();
      if (newCardError) {
        throw new Error(`Error creando tarjeta: ${newCardError.message}`);
      }
      cardId = newCard.id;
      currentPoints = 0;
      totalPointsLifetime = 0;
      rewardsClaimed = 0;
    }
    // ==========================================
    // PASO 4: Registrar el escaneo
    // ==========================================
    const { error: scanError } = await supabaseClient.from('scans').insert({
      user_id,
      business_id: business.id,
      qr_code_id,
      loyalty_card_id: cardId
    });
    if (scanError) {
      throw new Error(`Error registrando escaneo: ${scanError.message}`);
    }
    // ==========================================
    // PASO 5: Actualizar la tarjeta
    // ==========================================
    const newPoints = currentPoints + 1;
    const isRewardComplete = newPoints >= business.points_required;
    const { data: updatedCard, error: updateError } = await supabaseClient.from('loyalty_cards').update({
      current_points: isRewardComplete ? 0 : newPoints,
      total_points_lifetime: totalPointsLifetime + 1,
      rewards_claimed: isRewardComplete ? rewardsClaimed + 1 : rewardsClaimed,
      last_scan_at: new Date().toISOString()
    }).eq('id', cardId).select().single();
    if (updateError) {
      throw new Error(`Error actualizando tarjeta: ${updateError.message}`);
    }
    // ==========================================
    // PASO 6: Si completó, crear registro de premio
    // ==========================================
    if (isRewardComplete) {
      const { error: rewardError } = await supabaseClient.from('rewards').insert({
        user_id,
        business_id: business.id,
        loyalty_card_id: cardId,
        reward_description: business.reward_description,
        points_used: business.points_required,
        status: 'pending'
      });
      if (rewardError) {
        console.error('Error creando premio:', rewardError);
      // No lanzar error, el escaneo ya fue exitoso
      }
    }
    // ==========================================
    // PASO 7: Registrar intento exitoso
    // ==========================================
    await supabaseClient.from('scan_attempts').insert({
      user_id,
      business_id: business.id,
      qr_code_id,
      success: true,
      failure_reason: null
    });
    // ==========================================
    // PASO 8: RESPUESTA EXITOSA
    // ==========================================
    return new Response(JSON.stringify({
      success: true,
      business_name: business.name,
      business_category: business.category,
      reward_description: business.reward_description,
      current_points: updatedCard.current_points,
      points_required: business.points_required,
      reward_completed: isRewardComplete,
      total_rewards_claimed: updatedCard.rewards_claimed,
      message: isRewardComplete ? `🎉 ¡Felicidades! Ganaste: ${business.reward_description}` : `✅ Punto agregado! Progreso: ${updatedCard.current_points}/${business.points_required}`
    }), {
      headers: {
        ...corsHeaders,
        'Content-Type': 'application/json'
      }
    });
  } catch (error) {
    console.error('Error en validate-scan:', error);
    return new Response(JSON.stringify({
      success: false,
      error: 'Error interno del servidor',
      details: error.message
    }), {
      headers: {
        ...corsHeaders,
        'Content-Type': 'application/json'
      },
      status: 500
    });
  }
});
